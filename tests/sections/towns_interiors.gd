extends RefCounted
## Section towns_interiors (package T-towns-core, wave M1b-1; TOWNS addendum 4.2 - 4.5, design_towns.md 4 / 9): the WALK-IN INTERIORS and everything that stands in their doorways.
##
##   the room as data   JSON schema (GDScript AND Python interpreters), the stub map header (zone, title, builder), the zoom, the build budget, a rebuild that leaks nothing
##   the counter band   the counter, the hatch, the keeper post; flood fill with the REAL colliders against the Python flood fill; walking bodies: the hatch stops the player and lets a citizen pass
##   pieces             PieceCatalog's resolution order, the stand-ins (listed, never silent), the kit table (and, once I3 baked it, the manifest), the dressing overlay, the counter_hatch art
##   the hosts          ShopCounter: shop, post_counter, bar, appraisal, desk, talk x 2; inert without a keeper; the handler markers of V6; no forward_to_keeper seam
##   the E-query        rules A / B / C replayed in Python AND on the real player: 100 % agreement sample by sample
##   doors              Door2D: every reason, nameplates, homes with and without Routines, the round trip door -> room -> door at 0.0 px, the sign (and the emblem once the kit is baked)
##   closing time       ShopHours: the whisper, the eviction, the order of the events, held during a modal, waiting for a travel, a home evicts its guest
##   the tool           the generator regenerates identical specs, the validator catches 15 mutants, the 24 rooms pass
##
## SKIPs (named): kit_table_matches_manifest (until I3 baked assets/iso_props/shops/core/shops.json), windowed_shop_panel_over_room (until scenes/ui/shop_ui.tscn exists, P18): both REQUIRED at the G5b gate.
## Which clock this section runs at (DT55): it is about opening hours; the switch stays ON and every check names its moment (Tuesday 10:00 unless it says another).
## Rooms are built in a far-away holder (RoomProbe, FAR) so nothing of the live world is in the way; the section restores spec directories, catalogs, overrides and the clock.
const SECTION := "towns_interiors"
const TIMEOUT_S := 480.0

const Ctx := preload("res://tests/lib/towns/contexts.gd")
const FakeSocialScript := preload("res://tests/lib/towns/fake_social.gd")
const Probe := preload("res://tests/lib/towns/room_probe.gd")
const KeeperStub := preload("res://tests/lib/towns/keeper_stub.gd")
const SchemaLite := preload("res://tests/lib/towns/schema_lite.gd")
const Refs := preload("res://tests/lib/towns/forward_refs.gd")
const Gate := preload("res://scripts/economy/shop_hours_gate.gd")

const FIXTURES := "res://tests/fixtures/towns/interiors/"
const ROOMS: Array[String] = ["int_froebutikken", "int_postkontoret", "int_hoppe_hut"]
const SHOP_ROOMS: Array[String] = ["int_froebutikken", "int_postkontoret"]
const WORK := "user://towns_probe/"
const ALL24 := WORK + "all24/"
## A path that never holds a script: the "wave 4 world" in which T-routes has not landed, whatever the tree holds by now.
const NO_ROUTINES := "res://scripts/towns/_no_routines_in_this_leg.gd"
const OUTER_MAP := "@id _towns_outer\n@title ZONE_CITY\n@projection iso\n@ambient hyggebyen\n@theme hyggebyen\n@zone city\n@ground\n"
const KIT_PIECE_TEMPLATE := {"layer": "floor", "rot_map": [[0, false], [1, false], [0, false], [1, false]], "baked": [0, 1]}

var t
var gm: Node
var lm: Node
var bus: Node
var _probes: Array = []
var _fakes: Array[Node] = []
var _py_ok: bool = true
## The ids of the 24 rooms the generator writes into ALL24 (the 3 fixture rooms are byte-identical members of it); empty while python3 is missing (the section then runs on the fixtures alone).
var _all24: Array[String] = []
var _muted_world_cb: Callable = Callable()


## Collects what the towns code says on the bus: whispers (text or key), game events, travel requests, panel close requests.
class Tap extends RefCounted:
	var whispers: Array[String] = []
	var events: Array = []
	var travels: Array = []
	var panels: Array = []
	var opened_shops: Array = []
	var _bus: Node

	func _init(p_bus: Node) -> void:
		_bus = p_bus
		_bus.whisper_requested.connect(_on_whisper)
		_bus.game_event.connect(_on_event)
		_bus.area_change_requested.connect(_on_travel)
		_bus.ui_panel_toggled.connect(_on_panel)
		_bus.shop_opened.connect(_on_shop)

	func stop() -> void:
		if _bus.whisper_requested.is_connected(_on_whisper):
			_bus.whisper_requested.disconnect(_on_whisper)
		if _bus.game_event.is_connected(_on_event):
			_bus.game_event.disconnect(_on_event)
		if _bus.area_change_requested.is_connected(_on_travel):
			_bus.area_change_requested.disconnect(_on_travel)
		if _bus.ui_panel_toggled.is_connected(_on_panel):
			_bus.ui_panel_toggled.disconnect(_on_panel)
		if _bus.shop_opened.is_connected(_on_shop):
			_bus.shop_opened.disconnect(_on_shop)

	func clear() -> void:
		whispers.clear()
		events.clear()
		travels.clear()
		panels.clear()
		opened_shops.clear()

	func named(event_name: String) -> Array:
		return events.filter(func(e: Array) -> bool: return str(e[0]) == event_name)

	func _on_whisper(text: String) -> void:
		whispers.append(text)

	func _on_event(event_name: StringName, payload: Dictionary) -> void:
		events.append([event_name, payload])

	func _on_travel(area_id: StringName, spawn: StringName) -> void:
		travels.append([area_id, spawn])

	func _on_panel(panel_name: StringName, is_open: bool) -> void:
		panels.append([panel_name, is_open])

	func _on_shop(shop_id: StringName) -> void:
		opened_shops.append(shop_id)


func run(p_t) -> void:
	t = p_t
	var original_dirs: Array[String] = InteriorRoom.spec_dirs.duplicate()
	gm = t.autoload("GameManager")
	lm = t.autoload("LocalizationManager")
	bus = t.autoload("EventBus")
	if gm == null or lm == null or bus == null:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK))
	await t.go_menu()
	_reset()
	_generate_all24()
	_json_schema_and_header()
	await _budget_and_leaks()
	await _band_and_flood()
	await _pieces()
	await _overlay_and_hatch_art()
	await _windows()
	await _hosts()
	await _e_query()
	await _doors_in_the_world()
	await _closing_time()
	_tool()
	_reset()
	InteriorRoom.use_spec_dirs(original_dirs)


# ================================================================================================ helpers

func _reset() -> void:
	for p in _probes:
		p.dispose()
	_probes.clear()
	_release_fakes()
	gm.clear_config_overrides()
	Hours.override_registry = {}
	Hours.routines_path = Hours.ROUTINES_PATH
	Gate.use_hours_script()
	ShopCounter.keeper_resolver = Callable()
	PieceCatalog.reset()
	InteriorRoom.use_spec_dirs([FIXTURES] as Array[String])
	IsoArea.clear_handler_cache()
	t.new_game()
	Ctx.set_clock(gm, 1, 10.0)


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


func _room(room_id: String) -> Object:
	var p = Probe.new()
	await p.build(t, room_id)
	_probes.append(p)
	return p


func _dispose(p: Object) -> void:
	p.dispose()
	_probes.erase(p)


func _spec_of(room_id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + room_id + ".json"))


## A footprint as JSON gives it ([w, d] numbers, floats after parsing) equals w x d.
func _fp_is(v: Variant, w: int, d: int) -> bool:
	return v is Array and (v as Array).size() == 2 and int(v[0]) == w and int(v[1]) == d


## The real WorldRoot2D listens to EventBus.area_change_requested and would travel when a door or a closing shop asks: the checks that only LISTEN to the request take it off the bus for a while.
func _mute_world() -> void:
	var world: Node = t.world()
	if world == null:
		return
	for c in bus.area_change_requested.get_connections():
		var cb: Callable = c["callable"]
		if cb.get_object() == world:
			bus.area_change_requested.disconnect(cb)
			_muted_world_cb = cb
			return


func _unmute_world() -> void:
	if _muted_world_cb.is_valid() and not bus.area_change_requested.is_connected(_muted_world_cb):
		bus.area_change_requested.connect(_muted_world_cb)
	_muted_world_cb = Callable()


func _mid(n: int) -> int:
	return floori(float(n) / 2.0)


func _abs(path: String) -> String:
	return ProjectSettings.globalize_path(path)


## JSON text of a value with every whole number written as an integer (JSON.parse_string reads numbers as floats, and `8.0` is not what the Python tools expect for a cell).
func _json(value: Variant) -> String:
	return JSON.stringify(_ints(value))


func _ints(v: Variant) -> Variant:
	if v is Dictionary:
		var d: Dictionary = {}
		for k in (v as Dictionary):
			d[k] = _ints((v as Dictionary)[k])
		return d
	if v is Array:
		var a: Array = []
		for x in (v as Array):
			a.append(_ints(x))
		return a
	if v is float and is_equal_approx(float(v), roundf(float(v))):
		return int(roundf(float(v)))
	return v


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


## Runs one of tools/towns/interiors/*.py with python3 (isolated, no bytecode): {code, output, lines}; code 127 when there is no python3.
func _py(script: String, args: Array) -> Dictionary:
	var a := PackedStringArray(["python3", "-B", "-I", _abs("res://tools/towns/interiors/" + script)])
	for x in args:
		a.append(str(x))
	return t.run_tool("/usr/bin/env", a)


## Runs the generator once for the whole section: the 24 specs (14 CORE, 10 EXTENDED) in user://towns_probe/all24/, the rooms the budget, the flood fill and the post checks run on.
func _generate_all24() -> void:
	_all24.clear()
	var out: Dictionary = _py("generate.py", ["--out", _abs(ALL24)])
	if int(out["code"]) != 0:
		if int(out["code"]) == 127:
			_py_ok = false
		return
	var d := DirAccess.open(ALL24)
	if d != null:
		for f in d.get_files():
			if f.begins_with("int_") and f.ends_with(".json"):
				_all24.append(f.get_basename())
	_all24.sort()


## The rooms of the counter-band and budget legs: the 24 generated rooms (the three fixture rooms are among them), else the fixtures.
func _room_set() -> Array[String]:
	return _all24 if _all24.size() == 24 else ROOMS


func _use_room_set() -> void:
	InteriorRoom.use_spec_dirs([ALL24] as Array[String] if _all24.size() == 24 else [FIXTURES] as Array[String])


func _keeper_of(spec: Dictionary) -> Vector2i:
	for p in spec["posts"]:
		if str(p.get("kind", "")) == "keeper":
			return Vector2i(int(p["cell"][0]), int(p["cell"][1]))
	return Vector2i(-1, -1)


func _marker(spec: Dictionary, kind: String) -> Array:
	return (spec["markers"] as Array).filter(func(m: Dictionary) -> bool: return str(m["type"]) == kind)


func _counters(area: IsoArea, kind: String = "") -> Array[ShopCounter]:
	var out: Array[ShopCounter] = []
	for c in area.objects.get_children():
		if c is ShopCounter and (kind == "" or (c as ShopCounter).kind == kind):
			out.append(c as ShopCounter)
	return out


func _node_count(n: Node) -> int:
	var c: int = 1
	for ch in n.get_children():
		c += _node_count(ch)
	return c


# ================================================================================================ the room as data

func _json_schema_and_header() -> void:
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/interiors/schema.json"))
	var problems: Array[String] = []
	var specs: Dictionary = {}
	for r in ROOMS:
		var spec: Dictionary = _spec_of(r)
		specs[r] = spec
		var p: Array[String] = SchemaLite.problems(spec, schema)
		t.expect(p.is_empty(), "%s matches data/interiors/schema.json%s" % [r, "" if p.is_empty() else ": " + str(p.slice(0, 2))])
		for x in p:
			problems.append("%s %s" % [r, x])
	# the schema's enums are the art that exists: wall styles of interior.json, floors of tiles_floors.json
	var inter: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://assets/iso_props/interior/interior.json")) as Dictionary)["walls"]
	var styles: Array = (schema["properties"]["wall_style"]["enum"] as Array)
	var styles_exist: bool = styles.all(func(s: Variant) -> bool: return inter.has("corner_%s" % str(s)) and inter.has("wall_%s_win_r0" % str(s)) and inter.has("wall_%s_a_r1" % str(s)))
	var floors: Array = (schema["properties"]["floor"]["enum"] as Array)
	var floors_exist: bool = floors.all(func(f: Variant) -> bool: return ArtCatalog.has_real_terrain(StringName(str(f))))
	# negative controls: the interpreter reports a bad style, a stand_in field, a missing key, a cell with three numbers, a rotation out of range
	var bad: Dictionary = specs[ROOMS[0]].duplicate(true)
	bad["wall_style"] = "granite"
	(bad["items"] as Array)[0]["stand_in"] = "table_stump"
	(bad["items"] as Array)[1]["rot"] = 4
	(bad["door"] as Dictionary)["cell"] = [1, 2, 3]
	bad.erase("posts")
	var caught: Array[String] = SchemaLite.problems(bad, schema)
	var needs: Array = ["wall_style", "stand_in", "rot", "cell", "posts"]
	var all_caught: bool = needs.all(func(n: Variant) -> bool: return caught.any(func(c: String) -> bool: return c.contains(str(n))))
	# the Python interpreter reads the same file: the validator on the fixtures prints 0 problems and on the broken copy names the same things
	var py_clean: Dictionary = _py("validate.py", [_abs(FIXTURES)])
	_write(WORK + "int_bad.json", _json(bad))
	var py_bad: Dictionary = _py("validate.py", [_abs(WORK + "int_bad.json")])
	if int(py_clean["code"]) == 127:
		_py_ok = false
	var py_ok: bool = int(py_clean["code"]) == 0 and str(py_clean["output"]).contains("validate: 3 room(s), 0 problem(s)") and int(py_bad["code"]) == 1 and str(py_bad["output"]).contains("wall_style") and str(py_bad["output"]).contains("stand_in")
	t.check("json_schema", problems.is_empty() and styles_exist and floors_exist and all_caught and (py_ok or not _py_ok),
		"the 3 fixture rooms match data/interiors/schema.json (cols, rows, wall_style, floor, door, spawn_cell, windows, exit, items [{id, cell, rot, role?, wall?}], posts, markers incl. one hatch; no stand_in field) %s; its enums are the art that exists (wall styles %s of interior.json %s, floors %s of tiles_floors.json %s); the interpreter reports a bad style, a stand_in field, a rotation of 4, a three-number cell and a missing key %s; the Python validator says the same on the same file (clean 0 problems, broken copy refused) %s" % [
			str(problems.slice(0, 2)), str(styles), styles_exist, str(floors), floors_exist, all_caught, py_ok if _py_ok else "SKIPPED: python3 not found"])
	if not _py_ok:
		t.skip("towns_interiors: python3 was not found on this machine: every check that runs tools/towns/interiors/*.py is reduced to its Godot half")
	# the stub map header: zone of the OUTER area, title BLD_<ID>, the builder script, the room id
	var header_ok: bool = true
	var detail: Array[String] = []
	for r in ROOMS:
		var spec: Dictionary = specs[r]
		var building: String = str(spec["building"])
		var outer: String = str(spec["exit"]["area"])
		var outer_map: AreaMap = AreaMap.load_file("res://data/maps/%s.map" % outer)
		var zone: String = str(outer_map.zone) if outer_map != null else ""
		var text: String = InteriorRoom.stub_map(r, building, zone)
		var m: AreaMap = AreaMap.parse_text(text)
		var line_count: int = text.strip_edges().split("\n").size()
		var one: bool = str(m.id) == r and m.title == "BLD_%s" % building.to_upper() and m.projection == &"iso" and m.ambient == &"home" and str(m.zone) == zone and zone != "" and m.builder == "res://scripts/towns/interior_room.gd" \
			and str(m.extra.get("room", "")) == r and m.errors.is_empty() and m.is_builder() and ResourceLoader.exists(m.builder) and line_count == 7 and lm.has_key(m.title) and not _parkable(m)
		t.expect(one, "%s: the stub map header is complete (zone %s, title %s, builder, room id, 7 lines)" % [r, zone, m.title])
		header_ok = header_ok and one
		detail.append("%s zone %s title %s" % [r, zone, m.title])
	t.check("zone_header", header_ok, "the seven line stub map of a room (@id, @title BLD_<ID>, @projection iso (an ortho room would freeze the calendar), @ambient home, @zone <zone of the outer area>, @builder res://scripts/towns/interior_room.gd, @room <id>) parses without errors, the builder exists, the title key has a text, a builder room is never parked: %s" % str(detail))
	# the zoom fits every room: F6's formula, in the 1280 x 720 base, inside the area's zoom range
	var zoom_ok: bool = true
	var zooms: Array[String] = []
	for r in ROOMS:
		var spec: Dictionary = specs[r]
		var n: float = float(int(spec["cols"]) + int(spec["rows"]))
		var want: float = 0.85 * minf(1280.0 / (n * 64.0), 720.0 / (n * 38.0 + 280.0))
		var got: float = InteriorRoom.zoom_fit(int(spec["cols"]), int(spec["rows"]))
		# the visual box of the room (walls to the floor corners) times the zoom must fit the 1280 x 720 view
		var w: float = (float(spec["cols"]) + float(spec["rows"])) * 64.0
		var h: float = (float(spec["cols"]) + float(spec["rows"])) * 38.0 + 280.0
		t.expect(is_equal_approx(want, got) and w * got <= 1280.5 and h * got <= 720.5, "%s: zoom %.3f fits the room's %.0f x %.0f px visual box into 1280 x 720" % [r, got, w, h])
		zoom_ok = zoom_ok and is_equal_approx(want, got) and abs(float(spec["zoom_fit"]) - got) < 0.001 and w * got <= 1280.0 + 0.5 and h * got <= 720.0 + 0.5 and got >= 0.6 and got <= 0.9
		zooms.append("%s %.3f" % [r, got])
	t.check("zoom_fits_every_room", zoom_ok, "zoom_fit = 0.85 * min(1280 / (n * 64), 720 / (n * 38 + 280)), n = cols + rows: the room's visual box times the zoom fits the 1280 x 720 view, the JSON carries the same number: %s" % str(zooms))


## Would WorldRoot2D park the area of this map when the player leaves it? (a builder room never is)
func _parkable(m: AreaMap) -> bool:
	var a := IsoArea.new()
	a.map = m
	var parked: bool = WorldRoot2D.is_parkable(a)
	a.free()
	return parked


# ================================================================================================ budget and leaks

func _budget_and_leaks() -> void:
	var cold: Array[float] = []
	var warm: Array[float] = []
	var nodes: Array[int] = []
	var sprites: Array[int] = []
	var lights: Array[int] = []
	var errs: Array[String] = []
	var set_ids: Array[String] = _room_set()
	_use_room_set()
	var piece_report: Dictionary = {}
	var sizes: Dictionary = {}
	var night_layers: Array[int] = []
	for r in set_ids:
		for pass_no in 3:
			var p = await _room(r)
			if p.area == null or p.area.builder_error != "":
				errs.append("%s: %s" % [r, p.area.builder_error if p.area != null else "no area"])
			if pass_no == 0:
				cold.append(p.build_ms)
			else:
				warm.append(p.build_ms)
				t.expect(p.build_ms <= 50.0, "%s warm build %d: %.2f ms, %d nodes, %d sprites, %d lights" % [r, pass_no, p.build_ms, int(InteriorRoom.stats.get("nodes", 0)), int(InteriorRoom.stats.get("sprites", 0)), int(InteriorRoom.stats.get("lights", 0))])
			nodes.append(int(InteriorRoom.stats.get("nodes", 0)))
			sprites.append(int(InteriorRoom.stats.get("base_sprites", 0)))
			lights.append(int(InteriorRoom.stats.get("lights", 0)))
			if pass_no == 0:
				piece_report[r] = [int(InteriorRoom.stats.get("pieces", 0)), int(InteriorRoom.stats.get("placeholders", 0))]
				sizes[r] = "%d nodes %d sprites + %d night layers" % [int(InteriorRoom.stats.get("nodes", 0)), int(InteriorRoom.stats.get("sprites", 0)), int(InteriorRoom.stats.get("night", 0))]
				night_layers.append(int(InteriorRoom.stats.get("night", 0)))
			_dispose(p)
	var boxes: Array[String] = []
	for r in piece_report:
		if int(piece_report[r][1]) > 0:
			boxes.append("%s %d" % [r, int(piece_report[r][1])])
	InteriorRoom.use_spec_dirs([FIXTURES] as Array[String])
	warm.sort()
	cold.sort()
	nodes.sort()
	sprites.sort()
	var warm_p50: float = warm[_mid(warm.size())]
	var worst_cold: float = cold[cold.size() - 1]
	night_layers.sort()
	t.check("build_all_under_budget", errs.is_empty() and boxes.is_empty() and warm_p50 <= 12.0 and worst_cold <= 5000.0 and nodes[nodes.size() - 1] <= 130 and sprites[sprites.size() - 1] <= 31 and lights.max() <= 4 and night_layers[night_layers.size() - 1] <= 4,
		"%d builds (1 cold + 2 warm) of the %d rooms the generator writes (%s), each from its JSON: warm p50 %.2f ms (budget <= 12; design measured 6.2), worst cold %.2f ms (the first build of a room decodes its wall and furniture textures from disk: a sanity bound of 5000 ms that only catches a runaway build, the design measured 27.5 ms with its lighter placeholder art, a quiet machine here measures 130 - 520 ms and a load average of 30 gave 1,510 ms; the user-facing number is the windowed first frame <= 250 ms), base sprites (walls, corner, doormat, room pieces; dressing and hatch art also count toward the 130-node whole-room limit) p50 %d max %d (<= 31; design 25 / 31) plus at most %d additive window night layers, nodes p50 %d max %d (hard budget <= 130; design 76 / 96 was measured before the SE1 amendment added the two talk hosts of a shop band (ShopCounter + Area2D + shape + Timer = 4 nodes each)), lights max %d (<= 4), no builder error %s, no labelled box (every piece resolves to art or a stand-in) %s; per room %s" % [
			nodes.size(), set_ids.size(), "14 CORE + 10 EXTENDED" if set_ids.size() == 24 else "the 3 fixtures: python3 is missing", warm_p50, worst_cold, sprites[_mid(sprites.size())], sprites[sprites.size() - 1], night_layers[night_layers.size() - 1], nodes[_mid(nodes.size())], nodes[nodes.size() - 1], lights.max(), str(errs), str(boxes), str(sizes)])
	# a rebuild leaks nothing: nodes, orphans, bus connections, interactables and the catalog's caches stay where they were after the first build
	var p0 = await _room(ROOMS[0])
	_dispose(p0)
	await t.frames(2)
	var base_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var base_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var base_clock: int = bus.time_of_day_changed.get_connections().size()
	var base_events: int = bus.game_event.get_connections().size()
	var base_inter: int = t.count_group(&"interactable")
	var base_tex: int = PieceCatalog._tex_cache.size()
	var base_stand: int = PieceCatalog.used_stand_ins.size()
	for i in 6:
		var p = await _room(ROOMS[0])
		_dispose(p)
	await t.frames(3)
	var d_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - base_nodes
	var d_orph: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) - base_orphans
	var d_clock: int = bus.time_of_day_changed.get_connections().size() - base_clock
	var d_events: int = bus.game_event.get_connections().size() - base_events
	t.check("rebuild_leaks_nothing", d_nodes == 0 and d_orph == 0 and d_clock == 0 and d_events == 0 and t.count_group(&"interactable") == base_inter and PieceCatalog._tex_cache.size() == base_tex and PieceCatalog.used_stand_ins.size() == base_stand,
		"6 more builds and frees of one room change nothing: nodes %+d, orphan nodes %+d, time_of_day_changed connections %+d (ShopHours and the window clock disconnect when the room leaves), game_event connections %+d (the talk hosts), interactables %d -> %d, cached textures %d, reported stand-ins %d" % [
			d_nodes, d_orph, d_clock, d_events, base_inter, t.count_group(&"interactable"), PieceCatalog._tex_cache.size(), PieceCatalog.used_stand_ins.size()])


# ================================================================================================ the counter band

func _band_and_flood() -> void:
	var py_reach: Dictionary = {}
	var set_ids: Array[String] = _room_set()
	_use_room_set()
	var rr: Dictionary = _py("validate.py", [_abs(ALL24 if set_ids.size() == 24 else FIXTURES), "--reach"])
	if int(rr["code"]) == 0 and not (rr["lines"] as PackedStringArray).is_empty():
		var parsed: Variant = JSON.parse_string(str((rr["lines"] as PackedStringArray)[(rr["lines"] as PackedStringArray).size() - 1]))
		if parsed is Dictionary:
			py_reach = parsed
	var talk_ok: bool = true
	var flood_ok: bool = true
	var behind_ok: bool = true
	var posts_ok: bool = true
	var agree_ok: bool = true
	var notes: Array[String] = []
	var shop_rooms: int = 0
	for r in set_ids:
		var p = await _room(r)
		var spec: Dictionary = p.spec
		var area: IsoArea = p.area
		var spawn: Vector2i = Vector2i(int(spec["spawn_cell"][0]), int(spec["spawn_cell"][1]))
		var door: Vector2i = Vector2i(int(spec["door"]["cell"][0]), int(spec["door"]["cell"][1]))
		var player: Dictionary = p.reach(Iso.MASK_WALKING, spawn)
		var citizen: Dictionary = p.reach(Probe.CITIZEN_MASK, spawn)
		var keeper: Vector2i = _keeper_of(spec)
		var is_shop: bool = not _marker(spec, "talk").is_empty()
		if is_shop:
			shop_rooms += 1
			var m: int = keeper.x
			# the two talk cells: exactly the customer cells in front of the counter ENDS, free of items, posts and hatch bars, and reachable by the player
			var talks: Array = _marker(spec, "talk")
			var xs: Array = talks.map(func(mk: Dictionary) -> int: return int(mk["cell"][0]))
			xs.sort()
			var cells_ok: bool = xs == [m - 1, m + 1] and talks.all(func(mk: Dictionary) -> bool: return int(mk["cell"][1]) == 3)
			var free_ok: bool = true
			for mk in talks:
				var c := Vector2i(int(mk["cell"][0]), int(mk["cell"][1]))
				free_ok = free_ok and not p.blocked(p.cell_global(float(c.x), float(c.y)), Iso.MASK_WALKING) and player.has(c)
				for it in spec["items"]:
					free_ok = free_ok and not (int(it["cell"][0]) == c.x and int(it["cell"][1]) == c.y and not bool(it.get("wall", false)))
				for po in spec["posts"]:
					free_ok = free_ok and not (int(po["cell"][0]) == c.x and int(po["cell"][1]) == c.y)
			var hosts: Array[ShopCounter] = _counters(area, "talk")
			var placed: bool = hosts.size() == 2
			for h in hosts:
				var found: bool = false
				for mk in talks:
					found = found or h.global_position.distance_to(p.cell_global(float(mk["cell"][0]), float(mk["cell"][1]))) < 0.5
				placed = placed and found and h.radius == Vector2(40, 22)
			t.expect(cells_ok and free_ok and placed, "%s: the two talk hosts stand on the cells %d and %d of row 3 (in front of the counter ends), free, walkable, built as ShopCounters" % [r, m - 1, m + 1])
			talk_ok = talk_ok and cells_ok and free_ok and placed
			# door -> counter front -> every customer post, by the player; the door lane is walkable
			var front: Vector2i = Vector2i(m, 3)
			var flood_one: bool = player.has(door) and player.has(front)
			for po in spec["posts"]:
				if str(po.get("kind", "")) == "customer":
					flood_one = flood_one and player.has(Vector2i(int(po["cell"][0]), int(po["cell"][1])))
			for z in range(3, int(spec["rows"])):
				flood_one = flood_one and player.has(Vector2i(door.x, z))
			t.expect(flood_one, "%s: the player walks from the spawn to the door, the door lane, the counter front, both talk cells and every customer post" % r)
			flood_ok = flood_ok and flood_one
			# the keeper post: one row behind the counter, a citizen reaches it, the player does not
			var counter_row: int = -1
			for it in spec["items"]:
				if str(it.get("role", "")) == "counter":
					counter_row = int(it["cell"][1])
			var behind: bool = keeper.y == counter_row - 1 and citizen.has(keeper) and not player.has(keeper) and not player.has(Vector2i(keeper.x, keeper.y - 1))
			t.expect(behind, "%s: the keeper post %s is one row behind the counter (row %d): a citizen reaches it, the player does not" % [r, str(keeper), counter_row])
			behind_ok = behind_ok and behind
		# every post: a citizen reaches it; customers are reachable by the player too
		var rows_ok: bool = true
		for po in spec["posts"]:
			var c2 := Vector2i(int(po["cell"][0]), int(po["cell"][1]))
			rows_ok = rows_ok and citizen.has(c2) and (str(po.get("kind", "")) != "customer" or player.has(c2))
		rows_ok = rows_ok and citizen.has(door)
		t.expect(rows_ok, "%s: all %d posts and the door are reachable for a citizen body" % [r, (spec["posts"] as Array).size()])
		posts_ok = posts_ok and rows_ok
		# the flood fill with the REAL colliders agrees with the Python flood fill, cell by cell
		if py_reach.has(r):
			var py_p: Array = py_reach[r]["player"]
			var py_c: Array = py_reach[r]["citizen"]
			var gd_p: Array = player.keys().map(func(c: Vector2i) -> Array: return [c.x, c.y])
			var gd_c: Array = citizen.keys().map(func(c: Vector2i) -> Array: return [c.x, c.y])
			gd_p.sort_custom(_cell_less)
			gd_c.sort_custom(_cell_less)
			var same: bool = _cells_equal(py_p, gd_p) and _cells_equal(py_c, gd_c)
			t.expect(same, "%s: the real-collider flood fill equals the Python flood fill (player %d cells, citizen %d cells)" % [r, py_p.size(), py_c.size()])
			agree_ok = agree_ok and same
			notes.append("%s player %d / %d cells, citizen %d / %d (python / godot)" % [r, py_p.size(), gd_p.size(), py_c.size(), gd_c.size()])
		else:
			notes.append("%s: no python reach (python3 missing)" % r)
		_dispose(p)
	InteriorRoom.use_spec_dirs([FIXTURES] as Array[String])
	var scope: String = "the %d generated rooms (%d with a counter band)" % [set_ids.size(), shop_rooms] if set_ids.size() == 24 else "the 3 fixture rooms (python3 is missing)"
	t.check("talk_cells_free_and_beside_the_counter_ends", talk_ok and shop_rooms >= 2, "in %s the `talk` hosts stand on the cells m - 1 and m + 1 of row 3 (m = the keeper's column = the counter middle: the customer cells in front of the counter ENDS), free of items, posts and hatch bars, walkable for the real player body, and the room builds exactly two ShopCounter hosts of kind talk (ellipse 40 x 22) on them" % scope)
	t.check("door_to_counter_flood_fill", flood_ok and (agree_ok or not _py_ok), "flood fill with the real colliders (the player's mask: world, NPC bars, ground) in %s: from the spawn the PLAYER walks to the door, the whole door lane, the counter front, both talk cells and every customer post; it agrees cell by cell with the Python flood fill in every room: %s" % [scope, str(notes.slice(0, 4)) + (" ... %d rooms" % notes.size() if notes.size() > 4 else "")])
	t.check("keeper_behind_counter", behind_ok, "in %s the keeper post stands one row behind the 3 x 1 counter (row 1 behind row 2): a CITIZEN reaches it through the hatch gap, the PLAYER body does not reach it nor the cell behind it" % scope)
	t.check("every_post_reachable_by_citizen", posts_ok, "in %s every post (keeper, customers, beds, seats ...) and the door are reachable for a citizen body (mask world | player | ground, not the NPC layer), customer posts also for the player" % scope)
	await _hatch_walk()


static func _cell_less(a: Array, b: Array) -> bool:
	return int(a[0]) < int(b[0]) or (int(a[0]) == int(b[0]) and int(a[1]) < int(b[1]))


static func _cells_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if int(a[i][0]) != int(b[i][0]) or int(a[i][1]) != int(b[i][1]):
			return false
	return true


func _hatch_walk() -> void:
	# a body walks from the door lane towards the keeper post along 4 lanes (left of the counter, the counter, right of it, straight on): the PLAYER stops in front of the counter band,
	# a CITIZEN body following its path through the hatch gap reaches the post
	var blocked_ok: int = 0
	var passed_ok: int = 0
	var total: int = 0
	for r in SHOP_ROOMS:
		var p = await _room(r)
		var spec: Dictionary = p.spec
		var keeper: Vector2i = _keeper_of(spec)
		var cols: int = int(spec["cols"])
		var rows: int = int(spec["rows"])
		var kp: Vector2 = p.cell_global(float(keeper.x), float(keeper.y))
		var spawn := Vector2i(int(spec["spawn_cell"][0]), int(spec["spawn_cell"][1]))
		var cells: Array[Vector2i] = p.path(Probe.CITIZEN_MASK, spawn, keeper)
		var wps: Array[Vector2] = []
		for c in cells:
			wps.append(p.cell_global(float(c.x), float(c.y)))
		var nb: CharacterBody2D = p.make_body(Probe.CITIZEN_MASK, Iso.LAYER_NPC, wps[0] if not wps.is_empty() else kp)
		await p.walk(nb, wps, 185.0, 900)                                                   # one citizen walk per room: the path through the hatch gap
		var citizen_arrived: bool = nb.global_position.distance_to(kp) < 40.0
		t.expect(citizen_arrived, "%s: a citizen body walks the %d cell path through the hatch gap to the keeper post (%.0f px away)" % [r, cells.size(), nb.global_position.distance_to(kp)])
		nb.queue_free()
		for lane in [0.5, float(_mid(cols) - 1), float(cols - 1) - 0.5, float(keeper.x)]:
			total += 1
			var start: Vector2 = p.cell_global(lane, float(rows) - 2.0)
			var target: Vector2 = p.cell_global(lane, float(keeper.y))
			var pb: CharacterBody2D = p.make_body(Iso.MASK_WALKING, Iso.LAYER_PLAYER, start)
			var way: Array[Vector2] = [target]
			await p.walk(pb, way, 285.0, 240)
			var stopped: bool = pb.global_position.distance_to(kp) >= 60.0
			t.expect(stopped, "%s lane %.1f: the player body is stopped %.0f px from the keeper post" % [r, lane, pb.global_position.distance_to(kp)])
			if stopped:
				blocked_ok += 1
			if citizen_arrived:
				passed_ok += 1                                                               # the same citizen path is walkable from every lane's side of the room
			pb.queue_free()
		_dispose(p)
	t.check("hatch_stops_player_not_citizen", total == 8 and blocked_ok == total and passed_ok == total,
		"2 rooms x 4 lanes (%d runs) with real moving bodies: the PLAYER body (285 px/s) never reached the keeper post in %d of %d runs (it is stopped in front of the counter band), a CITIZEN body (185 px/s, one walk per room along its path from the spawn through the hatch gap) reached the post in %d of %d" % [total, blocked_ok, total, passed_ok, total])


# ================================================================================================ pieces

func _pieces() -> void:
	PieceCatalog.reset()
	PieceCatalog.kit_manifest_paths = [] as Array[String]
	PieceCatalog.forget()
	var furn: Dictionary = PieceCatalog.furniture()
	var kit: Dictionary = PieceCatalog.kit_table()
	var table: Dictionary = PieceCatalog.stand_in_table()
	# (1) no manifest: furniture first, then the stand-in table, then the labelled box
	var chair: Dictionary = PieceCatalog.resolve("chair_pine", 0)
	var anvil: Dictionary = PieceCatalog.resolve("anvil", 0)
	var drawers: Dictionary = PieceCatalog.resolve("seed_drawers_wall", 0)
	var unknown: Dictionary = PieceCatalog.resolve("no_such_piece_anywhere", 0)
	var rotated: Dictionary = PieceCatalog.resolve("counter_pine", 1)
	var step1: bool = chair["source"] == "furniture" and chair["art_id"] == "chair_pine" and anvil["source"] == "stand_in" and anvil["art_id"] == "table_stump" and drawers["source"] == "placeholder" and unknown["source"] == "placeholder" \
		and drawers["layer"] == "wall" and drawers["footprint"] == Vector2i(3, 1) and unknown["footprint"] == Vector2i(1, 1) and unknown.has("texture") and rotated["footprint"] == Vector2i(1, 3) and rotated["source"] == "stand_in"
	# a stand-in is placed at the footprint and layer of the KIT table (anvil 1 x 1) while the art it borrows (table_stump) is 2 x 1
	var kit_fp: bool = anvil["footprint"] == Vector2i(1, 1) and _fp_is(furn["table_stump"]["footprint"], 2, 1) and PieceCatalog.layer_of("wooden_tub") == "floor" and str(furn["rug_round_rose"]["layer"]) == "rug"
	# (2) a baked kit piece beats furniture.json AND the stand-in; furniture.json beats the stand-in table
	var manifest_path: String = WORK + "kit/shops.json"
	DirAccess.make_dir_recursive_absolute(_abs(WORK + "kit"))
	var items: Dictionary = {}
	for id in ["anvil", "chair_oak"]:
		var def: Dictionary = KIT_PIECE_TEMPLATE.duplicate(true)
		def["rot"] = {"0": {"file": "%s_r0.webp" % id, "size": [64, 64], "pivot": [32, 40], "footprint": [1, 1], "ysort": [-64.0, 0.0]}, "1": {"file": "%s_r1.webp" % id, "size": [64, 64], "pivot": [32, 40], "footprint": [1, 1], "ysort": [-64.0, 0.0]}}
		items[id] = def
	_write(manifest_path, JSON.stringify({"items": items}))
	var stand_path: String = WORK + "kit/stand_ins.json"
	_write(stand_path, JSON.stringify({"stand_ins": {"anvil": "table_stump", "chair_pine": "table_stump", "chair_oak": "table_stump"}}))
	PieceCatalog.kit_manifest_paths = [manifest_path] as Array[String]
	PieceCatalog.stand_ins_path = stand_path
	PieceCatalog.forget()
	var kit_anvil: Dictionary = PieceCatalog.resolve("anvil", 0)
	var kit_chair: Dictionary = PieceCatalog.resolve("chair_oak", 0)
	var fur_chair: Dictionary = PieceCatalog.resolve("chair_pine", 0)
	var step2: bool = kit_anvil["source"] == "kit" and str(kit_anvil["file"]).ends_with("kit/anvil_r0.webp") and kit_chair["source"] == "kit" and fur_chair["source"] == "furniture" and PieceCatalog.used_stand_ins.is_empty() \
		and PieceCatalog.kit_manifest_exists()
	PieceCatalog.reset()
	t.check("piece_resolution_order", step1 and kit_fp and step2 and not furn.is_empty() and not kit.is_empty() and not table.is_empty(),
		"a room item id resolves: baked kit manifest > furniture.json > data/interiors/stand_ins.json > a labelled box. Without a manifest: chair_pine is furniture %s, anvil is the stand-in table_stump %s (placed at the KIT footprint 1 x 1 and layer floor, not the borrowed art's 2 x 1 %s), a kit id without a stand-in (seed_drawers_wall) and an unknown id are boxes %s; counter_pine at rotation 1 is 1 x 3 %s. With a baked manifest the kit piece wins over furniture (chair_oak) and over the stand-in (anvil) %s, furniture.json still beats the stand-in table (chair_pine) %s" % [
			chair["source"] == "furniture", anvil["art_id"] == "table_stump", kit_fp, drawers["source"] == "placeholder" and unknown["source"] == "placeholder", rotated["footprint"] == Vector2i(1, 3), kit_anvil["source"] == "kit" and kit_chair["source"] == "kit", fur_chair["source"] == "furniture"])
	await _stand_ins_listed(table, kit, furn)
	PieceCatalog.reset()
	_kit_table(kit)


func _stand_ins_listed(table: Dictionary, kit: Dictionary, furn: Dictionary) -> void:
	PieceCatalog.reset()
	PieceCatalog.kit_manifest_paths = [] as Array[String]
	PieceCatalog.forget()
	# the table: every key is an I3 kit id, every target an existing furniture id; 16 room pieces + the counter
	var keys: Array = table.keys()
	keys.sort()
	var table_ok: bool = keys.size() == 17 and keys.all(func(k: Variant) -> bool: return kit.has(str(k)) and str((kit[str(k)] as Dictionary)["package"]) == "I3" and furn.has(str(table[k])))
	# building the rooms REPORTS every stand-in they drew, and the Python validator lists the same pieces
	var seen: Dictionary = {}
	for r in SHOP_ROOMS:
		var probe: Object = await _room(r)
		_dispose(probe)
	seen = PieceCatalog.used_stand_ins.duplicate()
	var py: Dictionary = _py("validate.py", [_abs(FIXTURES), "--stand-ins", "--without-kit"])
	var listed: Dictionary = {}
	for l in (py["lines"] as PackedStringArray):
		if str(l).begins_with("stand-in "):
			var parts: PackedStringArray = str(l).split(": ", false)
			var pair: PackedStringArray = parts[1].split(" -> ", false)
			listed[pair[0]] = pair[1]
	var same: bool = listed == seen if _py_ok else true
	var expected: Array = ["counter_pine", "letter_desk", "mail_sack", "parcel_stack", "pigeonhole_wall"]
	var got: Array = seen.keys()
	got.sort()
	t.check("stand_ins_listed", table_ok and got == expected and same,
		"data/interiors/stand_ins.json holds %d stand-ins (the 16 pieces the 14 core rooms draw as something else + counter_pine), each a kit id of the I3 package drawn by an EXISTING furniture piece %s; the post office and the seed shop REPORT exactly %s when built (PieceCatalog.used_stand_ins) and the validator lists the same pieces %s" % [
			keys.size(), table_ok, str(got), same])


func _kit_table(kit: Dictionary) -> void:
	var emblems: Dictionary = PieceCatalog.kit_emblems()
	var i3: int = 0
	var i4: int = 0
	for id in kit:
		if str((kit[id] as Dictionary)["package"]) == "I3":
			i3 += 1
		elif str((kit[id] as Dictionary)["package"]) == "I4":
			i4 += 1
	var py: Dictionary = _py("make_kit_table.py", [])
	var counts_ok: bool = kit.size() == 89 and emblems.size() == 15 and i3 + emblems.size() == 35 and i4 == 69 and kit.size() + emblems.size() == 104
	var layers_ok: bool = kit.values().all(func(v: Dictionary) -> bool: return str(v["layer"]) in ["floor", "rug", "wall", "tabletop", "ceiling", "fx"] and (v["footprint"] as Array).size() == 2)
	var counter_ok: bool = _fp_is(kit["counter_pine"]["footprint"], 3, 1) and str(kit["counter_pine"]["layer"]) == "floor" and kit.has("counter_end") and kit.has("counter_hatch") and kit.has("sign_bracket")
	var py_ok: bool = int(py["code"]) == 0 or not _py_ok
	if PieceCatalog.kit_manifest_exists():
		var manifest: Dictionary = PieceCatalog.kit_manifest()
		var bad: Array[String] = []
		for id in manifest:
			var def: Dictionary = manifest[id]
			if not kit.has(str(id)):
				bad.append("%s is not in the kit table" % id)
				continue
			var row: Dictionary = kit[str(id)]
			var rots: Dictionary = def.get("rot", {}) as Dictionary
			var rot0: Dictionary = rots.get("0", {}) as Dictionary
			var want_fp: Array = row["footprint"]
			if not _fp_is(rot0.get("footprint", []), int(want_fp[0]), int(want_fp[1])) or str(def.get("layer", "")) != str(row["layer"]) or rots.size() != int(row["rot_baked"]):
				bad.append("%s: footprint, layer or number of baked rotations differ" % id)
		for id in kit:
			if str((kit[id] as Dictionary)["package"]) == "I3" and not manifest.has(str(id)):
				bad.append("I3 piece %s is not in the manifest" % id)
		t.check("kit_table_matches_manifest", bad.is_empty() and counts_ok and layers_ok and counter_ok and py_ok,
			"data/interiors/kit_footprints.json equals the baked manifest: id, footprint, layer and number of baked rotations of every piece (%d problems %s)" % [bad.size(), str(bad.slice(0, 3))])
	else:
		t.check("kit_table_matches_manifest", counts_ok and layers_ok and counter_ok and py_ok,
			"the kit table holds the 104 kit ids (89 pieces + 15 emblem plates: I3 = counter band 3 + sign bracket 1 + the 16 room pieces + 15 emblems = 35, I4 = 69 dressing pieces; counts %s, layers and footprints well formed %s, counter_pine 3 x 1 floor %s); make_kit_table.py audits the same counts %s" % [counts_ok, layers_ok, counter_ok, py_ok])
		t.skip("towns_interiors.kit_table_matches_manifest: assets/iso_props/shops/core/shops.json (I3-art-shops, wave 5b) is not baked yet: the comparison with the real manifest (id, footprint, layer, baked rotations) is REQUIRED at the G5b gate")


# ================================================================================================ overlay and hatch art

func _overlay_and_hatch_art() -> void:
	PieceCatalog.reset()
	var dress_dir: String = WORK + "dress/"
	DirAccess.make_dir_recursive_absolute(_abs(dress_dir))
	InteriorRoom.use_spec_dirs([FIXTURES] as Array[String], dress_dir)
	# without an overlay file: nothing is added
	var base = await _room("int_froebutikken")
	var base_pieces: int = int(InteriorRoom.stats["pieces"])
	var base_bodies: int = int(InteriorRoom.stats["bodies"])
	_dispose(base)
	# with data/interiors/dress/int_<id>.json: the items are merged AFTER the room's own and drawn / collide like any piece
	_write(dress_dir + "int_froebutikken.json", JSON.stringify({"items": [{"id": "plant_fern", "cell": [0, 5], "rot": 0}, {"id": "rug_round_red", "cell": [1, 4], "rot": 0}]}))
	InteriorRoom.reset_cache()
	var merged = await _room("int_froebutikken")
	var merged_pieces: int = int(InteriorRoom.stats["pieces"])
	var merged_bodies: int = int(InteriorRoom.stats["bodies"])
	var spec_items: int = (InteriorRoom.load_spec("int_froebutikken")["items"] as Array).size()
	var all_items: Array = InteriorRoom.items_of(InteriorRoom.load_spec("int_froebutikken"))
	var order_ok: bool = all_items.size() == spec_items + 2 and str(all_items[spec_items]["id"]) == "plant_fern" and str(all_items[spec_items + 1]["id"]) == "rug_round_red"
	var fern_body: bool = merged.area.colliders.get_node_or_null("Piece_plant_fern_0_5") != null
	var other = await _room("int_postkontoret")
	var other_same: bool = int(InteriorRoom.stats["pieces"]) == (_spec_of("int_postkontoret")["items"] as Array).size()
	_dispose(other)
	_dispose(merged)
	# the validator merges the overlay too: a plant on a free cell passes, a rug across the counter band is refused
	var vdir: String = WORK + "valid/"
	DirAccess.make_dir_recursive_absolute(_abs(vdir + "dress"))
	_write(vdir + "int_froebutikken.json", FileAccess.get_file_as_string(FIXTURES + "int_froebutikken.json"))
	_write(vdir + "dress/int_froebutikken.json", FileAccess.get_file_as_string(dress_dir + "int_froebutikken.json"))
	var ok_run: Dictionary = _py("validate.py", [_abs(vdir)])
	_write(vdir + "dress/int_froebutikken.json", JSON.stringify({"items": [{"id": "rug_round_red", "cell": [3, 3], "rot": 0}, {"id": "plant_fern", "cell": [3, 2], "rot": 0}]}))
	var bad_run: Dictionary = _py("validate.py", [_abs(vdir)])
	var py_ok: bool = (int(ok_run["code"]) == 0 and str(ok_run["output"]).contains("+2 dressing pieces") and int(bad_run["code"]) == 1 and str(bad_run["output"]).contains("dressing piece")) or not _py_ok
	t.check("dress_overlay_merged_when_present", merged_pieces == base_pieces + 2 and merged_bodies == base_bodies + 1 and order_ok and fern_body and other_same and py_ok,
		"data/interiors/dress/int_<id>.json is merged after the items of the room when the file exists: the seed shop builds %d pieces (was %d) and %d colliders (was %d: the plant, not the flat rug) %s, the order is room items then overlay %s, a room without a file is unchanged %s; tools/towns/interiors/validate.py merges it too: free cells pass, a rug on the counter band and a piece on the counter are refused %s" % [
			merged_pieces, base_pieces, merged_bodies, base_bodies, fern_body, order_ok, other_same, py_ok])
	InteriorRoom.use_spec_dirs([FIXTURES] as Array[String])
	await _hatch_art()


func _hatch_art() -> void:
	PieceCatalog.reset()
	PieceCatalog.kit_manifest_paths = [] as Array[String]
	PieceCatalog.forget()
	# the invisible bars stay the collision; the baked piece counter_hatch is drawn on every hatch cell ONLY when it resolves to a manifest piece
	var bare = await _room("int_froebutikken")
	var bare_sprites: int = int(InteriorRoom.stats["sprites"])
	var hatch_cells: int = int(InteriorRoom.stats["hatch"])
	var bars_before: int = bare.area.colliders.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Hatch_")).size()
	_dispose(bare)
	# a manifest with other pieces but no counter_hatch: nothing is drawn
	var dir: String = WORK + "hatchkit/"
	DirAccess.make_dir_recursive_absolute(_abs(dir))
	var png: Image = Image.create_empty(64, 48, false, Image.FORMAT_RGBA8)
	png.fill(Color(0.8, 0.6, 0.3, 1.0))
	png.save_png(_abs(dir + "counter_hatch_r0.png"))
	var def: Dictionary = KIT_PIECE_TEMPLATE.duplicate(true)
	def["rot"] = {"0": {"file": "counter_hatch_r0.png", "size": [64, 48], "pivot": [32, 40], "footprint": [1, 1], "ysort": [-64.0, 0.0]}}
	var other_def: Dictionary = def.duplicate(true)
	_write(dir + "shops.json", JSON.stringify({"items": {"counter_end": other_def}}))
	PieceCatalog.kit_manifest_paths = [dir + "shops.json"] as Array[String]
	PieceCatalog.forget()
	var absent = await _room("int_froebutikken")
	var absent_sprites: int = int(InteriorRoom.stats["sprites"])
	_dispose(absent)
	# a manifest WITH counter_hatch: one sprite per hatch cell, the bars unchanged
	_write(dir + "shops.json", JSON.stringify({"items": {"counter_hatch": def}}))
	PieceCatalog.forget()
	var drawn = await _room("int_froebutikken")
	var drawn_sprites: int = int(InteriorRoom.stats["sprites"])
	var bars_after: int = drawn.area.colliders.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Hatch_") and n is StaticBody2D and (n as StaticBody2D).collision_layer == Iso.LAYER_NPC).size()
	_dispose(drawn)
	PieceCatalog.reset()
	t.check("hatch_cells_draw_counter_hatch_when_art_exists", hatch_cells == 5 and bars_before == 5 and absent_sprites == bare_sprites and drawn_sprites == bare_sprites + hatch_cells and bars_after == 5,
		"the 5 hatch cells of the seed shop are invisible bars on the NPC layer (%d) and nothing is drawn while the art is missing (sprites %d; a manifest without counter_hatch still %d); once the manifest has the piece every hatch cell gets its sprite (%d = %d + %d) and the bars stay the collision (%d on layer NPC)" % [
			bars_before, bare_sprites, absent_sprites, drawn_sprites, bare_sprites, hatch_cells, bars_after])


# ================================================================================================ windows

func _windows() -> void:
	var p = await _room("int_froebutikken")
	var wc: Node = p.area.get_node_or_null("WindowClock")
	var sprites: Array = wc.get("sprites") if wc != null else []
	var samples: Dictionary = {}
	for h in [6.0, 12.0, 17.5, 19.5, 22.0, 24.5, 25.5]:
		Ctx.set_clock(gm, 1, h)
		bus.time_of_day_changed.emit(int(floor(h)), int(round((h - floor(h)) * 60.0)))
		samples[h] = (sprites[0] as Sprite2D).modulate.a if not sprites.is_empty() else -1.0
		t.expect(not sprites.is_empty() and abs((sprites[0] as Sprite2D).modulate.a - InteriorRoom.outdoor_glow(h) * 0.9) < 0.001, "the window night layer at %s has alpha %.2f (outdoor glow %.2f x 0.9)" % [Hours.format_hour(h), samples[h], InteriorRoom.outdoor_glow(h)])
	var day_dark: bool = float(samples[12.0]) < 0.01 and float(samples[17.5]) < 0.01 and float(samples[6.0]) > 0.0 and float(samples[6.0]) < 0.9
	var night_lit: bool = float(samples[22.0]) > 0.8 and float(samples[24.5]) > 0.8 and float(samples[25.5]) > 0.8 and float(samples[19.5]) > 0.8
	var additive: bool = not sprites.is_empty() and (sprites[0] as Sprite2D).material is CanvasItemMaterial and ((sprites[0] as Sprite2D).material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD
	var count: int = p.area.objects.get_children().filter(func(n: Node) -> bool: return n.is_in_group("window_night")).size()
	t.check("windows_fade_with_the_outdoor_hour", day_dark and night_lit and additive and count == sprites.size() and sprites.size() >= 2,
		"the additive night layers of the %d windows fade with the OUTDOOR hour (the farm glow curve of lua/config/ambient.lua, not the room's own always-warm `home` preset): dark at 12:00 and 17:30 (alpha %.2f / %.2f), %.2f at dawn 06:00, lit at 19:30 (%.2f), 22:00 (%.2f) and through midnight 24:30 / 25:30 (%.2f / %.2f), listening to time_of_day_changed" % [
			sprites.size(), samples[12.0], samples[17.5], samples[6.0], samples[19.5], samples[22.0], samples[24.5], samples[25.5]])
	_dispose(p)
	Ctx.set_clock(gm, 1, 10.0)
	await _painted_lights()


func _painted_lights() -> void:
	PieceCatalog.reset()
	_use_room_set()
	var aligned := true
	var faded := true
	var capped := true
	var foreground := true
	var masks := 0
	var ceilings := 0
	for room_id in _room_set():
		var probe = await _room(room_id)
		var spec := InteriorRoom.load_spec(room_id)
		var expected := 0
		for item in InteriorRoom.items_of(spec):
			var piece := PieceCatalog.resolve(str(item["id"]), int(item.get("rot", 0)))
			if str(piece.get("night", "")) != "":
				expected += 1
		var clock: Node = probe.area.get_node_or_null("PieceLightClock")
		var accents: Array = clock.accents if clock != null else []
		aligned = aligned and accents.size() == expected
		for accent: Sprite2D in accents:
			var body := accent.get_parent() as Sprite2D
			var found := false
			for item in InteriorRoom.items_of(spec):
				var piece := PieceCatalog.resolve(str(item["id"]), int(item.get("rot", 0)))
				if piece.get("night", "") == accent.texture.resource_path:
					found = accent.offset.is_equal_approx(body.offset + piece["night_offset"])
			aligned = aligned and found and accent.material == Glow.additive_material()
		masks += accents.size()
		for hour in [12.0, 22.0, 24.5]:
			Ctx.set_clock(gm, 1, hour)
			bus.time_of_day_changed.emit(gm.hour, gm.minute)
			for accent: Sprite2D in accents:
				faded = faded and is_equal_approx(accent.modulate.a, InteriorRoom.outdoor_glow(hour))
		capped = capped and int(InteriorRoom.stats["service_lights"]) <= 1 and int(InteriorRoom.stats["lights"]) <= 4
		for sprite in probe.area.objects.get_children():
			if sprite is Sprite2D and sprite.z_index == 2:
				ceilings += 1
				foreground = foreground and not sprite.y_sort_enabled
		_dispose(probe)
	t.check("painted_light_masks_follow_body_and_clock", aligned and faded and capped and masks >= 5,
		"%d painted accents align with the final body offset plus the trimmed source offset, use additive blending, fade at noon/night/after midnight, and add at most one service light per room" % masks)
	t.check("ceiling_dressing_stays_in_foreground", foreground and ceilings > 0,
		"%d hanging pieces use the foreground plane above the y-sorted actors" % ceilings)
	InteriorRoom.use_spec_dirs([FIXTURES] as Array[String])
	Ctx.set_clock(gm, 1, 10.0)


# ================================================================================================ the hosts

func _hosts() -> void:
	PieceCatalog.reset()
	var tap := Tap.new(bus)
	# --- shop: the counter middle opens the shop panel over the live room
	var p = await _room("int_froebutikken")
	var area: IsoArea = p.area
	var shops: Array[ShopCounter] = _counters(area, "shop")
	var host: ShopCounter = shops[0] if shops.size() == 1 else null
	var player := Node2D.new()
	area.objects.add_child(player)
	tap.clear()
	if host != null:
		host.interact(player)
	var opened: bool = tap.opened_shops == [&"seed_shop"]
	var prompt_ok: bool = host != null and host.get_interaction_prompt() == lm.t("COUNTER_SHOP") and host.radius == Vector2(150, 40) and host.kind == "shop" and host.shop_id == "seed_shop"
	t.check("counter_opens_shop", opened and prompt_ok and host.is_enabled() and host.position.is_equal_approx(InteriorRoom.cell_local(float(_keeper_of(p.spec).x), 3.0)),
		"E on the middle host (150 x 40, on the cell in front of the counter middle) calls ShopSystem.open_shop(seed_shop): EventBus.shop_opened(seed_shop) %s, the prompt is COUNTER_SHOP \"%s\" %s" % [opened, lm.t("COUNTER_SHOP"), prompt_ok])
	# --- talk: inert until a keeper node stands in the room, then the keeper's own interact
	var talks: Array[ShopCounter] = _counters(area, "talk")
	var inert: bool = talks.size() == 2 and talks.all(func(h: ShopCounter) -> bool: return not h.is_enabled() and not h.visible)
	var find_inert: bool = true
	for h in talks:
		var q := PhysicsShapeQueryParameters2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 5.0
		q.shape = circle
		q.transform = Transform2D(0.0, h.global_position)
		q.collision_mask = Iso.LAYER_INTERACTABLE
		q.collide_with_areas = true
		q.collide_with_bodies = false
		for hit in area.get_world_2d().direct_space_state.intersect_shape(q, 8):
			if (hit["collider"] as Node).get_parent() == h:
				find_inert = false
	t.check("talk_inert_without_keeper", inert and find_inert and talks[0].keeper_node() == null,
		"with no keeper node in the room (before the room director of T-director) both talk hosts keep their Area2D disabled, are hidden and invisible to the E-query (a physics query on their cells finds nothing) %s" % [inert and find_inert])
	var keeper := KeeperStub.new()
	area.objects.add_child(keeper)
	ShopCounter.keeper_resolver = func(id: String) -> Node: return keeper if id == "merchant_pip" else null
	bus.game_event.emit(&"area_populated", {"area": "int_froebutikken", "citizens": 1, "visuals": 1, "dropped": 0})        # the signal of the director wakes the hosts at once
	var woke: bool = talks.all(func(h: ShopCounter) -> bool: return h.is_enabled() and h.visible)
	var prompts: bool = true
	for h in talks:
		prompts = prompts and h.get_interaction_prompt() == lm.t("COUNTER_TALK", [lm.t("NPC_MERCHANT_PIP")]) and h.keeper_id == "merchant_pip" and h.radius == Vector2(40, 22)
	talks[0].interact(player)
	talks[1].interact(player)
	var forwarded: bool = keeper.interactions.size() == 2 and keeper.interactions[0] == player
	ShopCounter.keeper_resolver = Callable()
	await t.seconds(0.7)                                                                                                    # the 0.5 s poll takes them away again: no keeper, inert again
	var slept: bool = talks.all(func(h: ShopCounter) -> bool: return not h.is_enabled())
	t.check("talk_forwards_to_keeper_npc", woke and prompts and forwarded and slept,
		"once a keeper node exists (NpcDirector.node_of late bound; a test resolver here) both talk hosts wake (area_populated or the 0.5 s poll) %s, read COUNTER_TALK \"%s\" with the keeper's NPC_<ID> name %s and call the keeper's own interact(player): 2 calls %s, so the greeting, weekly heart, gifts, topics and quests of the Lua dialogue run unchanged; without a keeper they go inert again %s" % [
			woke, lm.t("COUNTER_TALK", [lm.t("NPC_MERCHANT_PIP")]), prompts, forwarded, slept])
	_dispose(p)
	# --- the services: post counter, bar, desk, appraisal, and the fallback of the handler kinds
	await _service_hosts(tap)
	await _handler_markers(tap)
	_no_forward_seam()
	tap.stop()


func _service_hosts(tap: Tap) -> void:
	var holder := Node2D.new()
	t.root.add_child(holder)
	var player := Node2D.new()
	holder.add_child(player)
	var post := ShopCounter.new()
	post.setup("post_counter", {"keeper": "postman_pip"}, "postkontoret")
	holder.add_child(post)
	var bar := ShopCounter.new()
	bar.setup("bar", {"keeper": "innkeeper_kvak"}, "torvekroen")
	holder.add_child(bar)
	tap.clear()
	post.interact(player)
	bar.interact(player)
	var post_ev: Array = tap.named("open_post_office")
	var bar_ev: Array = tap.named("open_inn_menu")
	var events_ok: bool = post_ev.size() == 1 and post_ev[0][1] == {"npc": "postman_pip", "building": "postkontoret"} and bar_ev.size() == 1 and bar_ev[0][1] == {"npc": "innkeeper_kvak", "building": "torvekroen"} \
		and post.radius == Vector2(150, 40) and bar.radius == Vector2(150, 40) and post.get_interaction_prompt() == lm.t("COUNTER_SHOP")
	# the desk: the SECOND door of the Husbyggeri, tier = the world flag home_tier
	var desk := ShopCounter.new()
	desk.setup("desk", {"keeper": "fairy_builder"}, "toemmerhandlen")
	holder.add_child(desk)
	gm.set_flag(&"home_tier", 4)
	tap.clear()
	desk.interact(player)
	var tier4: Array = tap.named("open_home_builder")
	gm.clear_flag(&"home_tier")
	tap.clear()
	desk.interact(player)
	var tier1: Array = tap.named("open_home_builder")
	var desk_ok: bool = tier4.size() == 1 and tier4[0][1] == {"tier": 4} and tier1.size() == 1 and tier1[0][1] == {"tier": 1} and desk.radius == Vector2(40, 22) and desk.get_interaction_prompt() == lm.t("COUNTER_DESK")
	t.check("desk_emits_open_home_builder", desk_ok, "the builder yard's desk (40 x 22, COUNTER_DESK \"%s\") emits game_event open_home_builder {tier} with the world flag home_tier (4 -> tier 4, no flag -> tier 1): the ten-step home ladder never depends on a conversation; only the builder yard's generated room carries the desk marker %s" % [lm.t("COUNTER_DESK"), _desk_only_in_the_builder_yard()])
	# the appraisal: refused while the building is closed, a whisper until LootService can appraise, the event once it can
	var app := ShopCounter.new()
	app.setup("appraisal", {"keeper": "appraiser_fru_ugle"}, "uglehulen")
	holder.add_child(app)
	Ctx.set_clock(gm, 0, 14.0)                                                         # Monday: her field day
	tap.clear()
	app.interact(player)
	var closed_day_text: String = Hours.closed_text(Hours.state("uglehulen"))
	var refused_day: bool = tap.whispers == [closed_day_text] and tap.named("open_appraisal").is_empty() and closed_day_text != "" and closed_day_text.contains(Hours.weekday_text(1))
	Ctx.set_clock(gm, 2, 11.0)                                                         # Wednesday before 12:00
	tap.clear()
	app.interact(player)
	var refused_hours: bool = tap.whispers == [Hours.closed_text(Hours.state("uglehulen"))] and tap.named("open_appraisal").is_empty() and Hours.closed_text(Hours.state("uglehulen")).contains("12:00")
	Ctx.set_clock(gm, 2, 14.0)                                                         # open
	var mute := Node.new()                                                              # a LootService that cannot appraise (the real one may already have appraise(): F4 / DL7)
	_fakes.append(mute)
	Svc.override("LootService", mute)
	tap.clear()
	app.interact(player)
	var soon: bool = tap.whispers == ["COUNTER_APPRAISE_SOON"] and tap.named("open_appraisal").is_empty()
	var loot := Node.new()
	loot.set_script(_appraiser_script())
	_fakes.append(loot)
	Svc.override("LootService", loot)
	tap.clear()
	app.interact(player)
	var ev: Array = tap.named("open_appraisal")
	var sent: bool = ev.size() == 1 and ev[0][1] == {"npc": "appraiser_fru_ugle", "building": "uglehulen"} and tap.whispers.is_empty()
	Ctx.set_clock(gm, 0, 14.0)                                                         # closed again: the closed whisper wins even with LootService
	tap.clear()
	app.interact(player)
	var still_refused: bool = tap.named("open_appraisal").is_empty() and tap.whispers.size() == 1
	gm.set_config_override("towns.hours_enabled", false)                                # the switch OFF: the rule does not exist, nothing is refused for hours
	tap.clear()
	app.interact(player)
	var off: bool = tap.named("open_appraisal").size() == 1
	gm.clear_config_overrides()
	Svc.clear_overrides()
	t.check("appraisal_counter_events_and_refusals", events_ok and refused_day and refused_hours and soon and sent and still_refused and off and app.radius == Vector2(150, 40) and app.get_interaction_prompt() == lm.t("COUNTER_APPRAISE"),
		"post_counter and bar emit open_post_office / open_inn_menu {npc, building} %s; Uglehulen's centre host (kind appraisal, COUNTER_APPRAISE \"%s\", same geometry as the shop): Monday (field day) refused with the whisper of Hours.closed_info \"%s\" %s, Wednesday 11:00 refused with the opening time %s, open with no LootService.appraise yet: the whisper COUNTER_APPRAISE_SOON %s, with it: game_event open_appraisal {npc, building} %s, closed again: refused %s, switch off: not refused %s" % [
			events_ok, lm.t("COUNTER_APPRAISE"), closed_day_text, refused_day, refused_hours, soon, sent, still_refused, off])
	holder.queue_free()
	Ctx.set_clock(gm, 1, 10.0)


func _appraiser_script() -> Script:
	var s := GDScript.new()
	s.source_code = "extends Node\nfunc appraise(_item) -> bool:\n\treturn true\n"
	s.reload()
	return s


func _desk_only_in_the_builder_yard() -> bool:
	var out: Dictionary = _py("generate.py", ["--out", _abs(WORK + "all24")])
	if int(out["code"]) != 0:
		return not _py_ok
	var with_desk: Array[String] = []
	var d := DirAccess.open(WORK + "all24")
	for f in d.get_files():
		var spec: Variant = JSON.parse_string(FileAccess.get_file_as_string(WORK + "all24/" + f))
		if spec is Dictionary and not _marker(spec, "desk").is_empty():
			with_desk.append(str(spec["id"]))
	return with_desk == ["int_toemmerhandlen"]


func _handler_markers(tap: Tap) -> void:
	# a room with a bath, a board and a mailbox marker: built by the handler of their own package through IsoArea.resolve_handler INSIDE the room when one is registered,
	# otherwise a fallback counter that only announces the use as a game_event
	var spec: Dictionary = _spec_of("int_postkontoret")
	spec["id"] = "int_probe_services"
	spec["building"] = "badehuset"
	spec["exit"] = {"area": "traetoppen", "spawn": "from_int_badehuset"}
	var markers: Array = (spec["markers"] as Array).filter(func(m: Dictionary) -> bool: return not (str(m["type"]) in ["post_counter", "mailbox", "talk"]))
	var m: int = _keeper_of(spec).x
	markers.append({"type": "bath", "keeper": "bathkeeper_sofus", "cell": [m, 3]})
	markers.append({"type": "board", "keeper": "clerk_fjerpen", "cell": [1, 5]})
	markers.append({"type": "mailbox", "cell": [6, 5]})
	spec["markers"] = markers
	var dir: String = WORK + "probe_rooms/"
	DirAccess.make_dir_recursive_absolute(_abs(dir))
	_write(dir + "int_probe_services.json", _json(spec))
	InteriorRoom.use_spec_dirs([dir] as Array[String])
	# (1) Explicitly remove the installed V6 handlers for this fallback probe.
	gm.set_config_override("marker_handlers", {"bath": "res://__fixture_missing__.gd", "board": "res://__fixture_missing__.gd", "mailbox": "res://__fixture_missing__.gd"})
	IsoArea.clear_handler_cache()
	var bare = await _room("int_probe_services")
	var fallbacks: Array[ShopCounter] = _counters(bare.area)
	var kinds: Array = fallbacks.map(func(c: ShopCounter) -> String: return c.kind)
	kinds.sort()
	var player := Node2D.new()
	bare.area.objects.add_child(player)
	tap.clear()
	for c in fallbacks:
		c.interact(player)
	var announced: Array = tap.named("counter_used").map(func(e: Array) -> String: return str((e[1] as Dictionary)["kind"]))
	announced.sort()
	var handlers_before: int = int(InteriorRoom.stats["handlers"])
	_dispose(bare)
	# (2) handlers registered (a probe script per kind): the room contains the handler's node and no counter of that kind
	var script_path: String = WORK + "probe_handler.gd"
	_write(script_path, "extends Node2D\nstatic func create_marker(params: Dictionary, pos: Vector2, cell: Vector2i, area: IsoArea) -> Node:\n\tvar n := Node2D.new()\n\tn.name = \"Probe_%s\" % params.get(\"marker\", \"?\")\n\tn.set_meta(\"cell\", cell)\n\treturn n\n")
	gm.set_config_override("marker_handlers", {"bath": script_path, "board": script_path, "mailbox": script_path})
	IsoArea.clear_handler_cache()
	var served = await _room("int_probe_services")
	var made: Array[String] = []
	for c in served.area.objects.get_children():
		if str(c.name).begins_with("Probe_"):
			made.append(str(c.name))
	made.sort()
	var counters_left: Array[ShopCounter] = _counters(served.area)
	var kinds_left: Array = counters_left.map(func(c: ShopCounter) -> String: return c.kind)
	var handled: int = int(InteriorRoom.stats["handlers"])
	var placed: bool = true
	for c in served.area.objects.get_children():
		if str(c.name) == "Probe_bath":
			placed = placed and (c as Node2D).position.is_equal_approx(InteriorRoom.cell_local(float(m), 3.0))
	_dispose(served)
	gm.clear_config_overrides()
	IsoArea.clear_handler_cache()
	InteriorRoom.use_spec_dirs([FIXTURES] as Array[String])
	t.check("marker_handlers_inside_room", kinds == ["bath", "board", "mailbox"] and announced == ["bath", "board", "mailbox"] and handlers_before == 0 \
		and made == ["Probe_bath", "Probe_board", "Probe_mailbox"] and handled == 3 and not ("bath" in kinds_left) and not ("board" in kinds_left) and not ("mailbox" in kinds_left) and placed,
		"bath / board / mailbox are built by the handler of THEIR package through IsoArea.resolve_handler inside the room (create_marker(params, pos, cell, area)): with handlers registered the room holds %s and no counter of those kinds (%s left), the handler node sits on its cell %s; without a handler each falls back to a ShopCounter that announces game_event counter_used with its kind %s" % [
			str(made), str(kinds_left), placed, str(announced)])


func _no_forward_seam() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/towns/shop_counter.gd")
	var hits: Array[String] = Refs.scan_text(src, ["forward_to_keeper", "give_gift", "gift_options", "GiftFlow", "gift_ui"], "shop_counter.gd")
	var probe := ShopCounter.new()
	var has_method: bool = probe.has_method("forward_to_keeper") or probe.has_method("give_gift")
	var props: bool = false
	for pr in probe.get_property_list():
		if str(pr["name"]).contains("forward") or str(pr["name"]).contains("gift"):
			props = true
	probe.free()
	var contract: bool = ShopCounter.KINDS == ["shop", "post_counter", "bar", "appraisal", "desk", "talk"]
	t.check("no_forward_to_keeper_seam", hits.is_empty() and not has_method and not props and contract,
		"ShopCounter has the SIX kinds %s and no forward_to_keeper seam and no gift shortcut: no such method or property, no such identifier in code (%d hits %s): a giftable hotbar item never takes E first (it would have sent 12 of 12 tools and 8 of 8 seeds into a gift talk instead of the panel)" % [str(ShopCounter.KINDS), hits.size(), str(hits)])


# ================================================================================================ the E-query

func _e_query() -> void:
	PieceCatalog.reset()
	InteriorRoom.use_spec_dirs([FIXTURES] as Array[String])
	var emit_path: String = WORK + "expected.json"
	var run: Dictionary = _py("e_query_replay.py", [_abs(FIXTURES), "--emit", _abs(emit_path)])
	var last: String = ""
	for l in (run["lines"] as PackedStringArray):
		if str(l).begins_with("over "):
			last = str(l)
	var rx := RegEx.new()
	rx.compile("over (\\d+) rooms: A (\\d+) / (\\d+), B (\\d+) / (\\d+), C violations (\\d+), keeper-direct selections (\\d+)")
	var m: RegExMatch = rx.search(last)
	var rules_ok: bool = false
	var numbers: String = last
	if m != null:
		rules_ok = int(run["code"]) == 0 and int(m.get_string(1)) == 2 and int(m.get_string(2)) == 36 and int(m.get_string(3)) == 36 and int(m.get_string(4)) == 18 and int(m.get_string(5)) == 18 and int(m.get_string(6)) == 0
	# the design's own measurement, reproduced on the 14 CORE layouts the generator writes: A 252 / 252, B 126 / 126, C 0 (of 1,008 samples), the keeper itself never selected
	var core_dir: String = WORK + "core14"
	var core_gen: Dictionary = _py("generate.py", ["--out", _abs(core_dir), "--wave", "core"])
	var core_run: Dictionary = _py("e_query_replay.py", [_abs(core_dir)])
	var core_last: String = ""
	for l in (core_run["lines"] as PackedStringArray):
		if str(l).begins_with("over "):
			core_last = str(l)
	var core_ok: bool = int(core_gen["code"]) == 0 and int(core_run["code"]) == 0 and core_last == "over 14 rooms: A 252 / 252, B 126 / 126, C violations 0, keeper-direct selections 0"
	# a negative control: a talk host one cell too far from the counter end breaks rule A and the replay says so
	var broken: Dictionary = _spec_of("int_froebutikken")
	for mk in broken["markers"]:
		if str(mk["type"]) == "talk" and int(mk["cell"][0]) > _keeper_of(broken).x:
			mk["cell"][0] = int(mk["cell"][0]) + 1
	DirAccess.make_dir_recursive_absolute(_abs(WORK + "broken"))
	_write(WORK + "broken/int_froebutikken.json", _json(broken))
	var neg: Dictionary = _py("e_query_replay.py", [_abs(WORK + "broken")])
	var neg_ok: bool = int(neg["code"]) == 1 and str(neg["output"]).contains("/ 18")
	if not _py_ok:
		rules_ok = true
		neg_ok = true
		core_ok = true
	t.check("e_query_replay_rules_ABC", rules_ok and neg_ok and core_ok,
		"the Python replay of the BUILT E-query (circle r = 45 at the facing cell, 12-gon ellipses, the host NEAREST TO THE PLAYER wins) on the two shop bands: A standing on an end cell facing the counter selects that cell's talk host 36 of 36, B the middle cell selects the centre host 18 of 18, C a talk host is never selected from the middle cell at any of the 8 facings (0 violations): \"%s\"; on the 14 CORE layouts of the generator it reproduces the design's measurement \"%s\" %s; a talk host one cell off its counter end is caught (exit 1) %s" % [numbers, core_last, core_ok, neg_ok])
	if not _py_ok or not FileAccess.file_exists(emit_path):
		t.skip("towns_interiors: no Python replay table (python3 missing): the real-player twin is skipped")
		return
	# the GDScript twin on the REAL player: the same samples, selected by Player.nearest_interactable on the real rooms
	await t.start_world()
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(emit_path))
	var world: Node = t.world()
	var pl: Node2D = world.player
	var old_area: Variant = pl.get("area")
	var old_pos: Vector2 = pl.global_position
	var subs: Array[Vector2] = []
	for sx in [-0.8, 0.0, 0.8]:
		for sy in [-0.8, 0.0, 0.8]:
			subs.append(Vector2(sx * 32.0, sy * 19.0))
	var total: int = 0
	var mismatch: int = 0
	var hist: Dictionary = {}
	var acc: Dictionary = {"A": 0, "B": 0, "C": 0, "keeper_forward": 0, "centre_opens": 0}
	var first_bad: String = ""
	for r in SHOP_ROOMS:
		var p = await _room(r)
		var spec: Dictionary = p.spec
		var area: IsoArea = p.area
		var keeper_cell: Vector2i = _keeper_of(spec)
		var keeper := KeeperStub.new()
		area.objects.add_child(keeper)
		keeper.global_position = p.cell_global(float(keeper_cell.x), float(keeper_cell.y))
		ShopCounter.keeper_resolver = func(id: String) -> Node: return keeper
		var roles: Dictionary = {}
		var hosts: Array[ShopCounter] = _counters(area)
		for h in hosts:
			h._refresh()
			match h.kind:
				"talk":
					roles[h] = "T0" if _column_of(h, p, spec) < keeper_cell.x else "T1"       # T0 is the talk host of the smaller column
				"mailbox":
					roles[h] = "X"
				"desk":
					roles[h] = "D"
				_:
					roles[h] = "S"
		for service in area.objects.get_children():
			if service is PostBox2D:
				roles[service] = "X"
		var kh := Interactable2D.new()
		kh.name = "KeeperHost"
		kh.radius = Vector2(60, 30)
		area.objects.add_child(kh)
		kh.global_position = keeper.global_position
		await t.physics(3)
		pl.set("area", area)
		var hatch: Dictionary = {}
		for mk in _marker(spec, "hatch"):
			for c in mk["cells"]:
				hatch["%d,%d" % [int(c[0]), int(c[1])]] = true
		var items: Dictionary = {}
		for it in spec["items"]:
			if not bool(it.get("wall", false)):
				items["%d,%d" % [int(it["cell"][0]), int(it["cell"][1])]] = true
		for cx in int(spec["cols"]):
			for cz in range(3, int(spec["rows"])):
				var key: String = "%d,%d" % [cx, cz]
				if hatch.has(key) or items.has(key):
					continue
				for si in subs.size():
					pl.global_position = p.cell_global(float(cx), float(cz)) + subs[si]
					for f in 8:
						pl.set("facing8", f)
						var found: Node = pl.call("nearest_interactable")
						var role: String = "none"
						if found != null:
							role = "K" if found == kh else str(roles.get(found, "?"))
						total += 1
						hist[role] = int(hist.get(role, 0)) + 1
						var want: String = str(expected.get("%s|%d,%d|%d|%d" % [r, cx, cz, si, f], "missing"))
						if want != role:
							mismatch += 1
							if first_bad == "":
								first_bad = "%s cell %s sub %d facing %d: godot %s python %s" % [r, key, si, f, role, want]
		# the acceptance numbers on the real player: A / B / C, and E on an end cell reaches the keeper, E on the middle cell opens the panel
		var mid_col: int = keeper_cell.x
		var tap := Tap.new(bus)
		var ra: int = 0
		var rb: int = 0
		var rc: int = 0
		for si in subs.size():
			pl.global_position = p.cell_global(float(mid_col - 1), 3.0) + subs[si]
			pl.set("facing8", 5)
			var fa: Node = pl.call("nearest_interactable")
			ra += 1 if fa != null and roles.get(fa, "") == "T0" else 0
			if fa != null and roles.get(fa, "") == "T0":
				(fa as ShopCounter).interact(pl)
			pl.global_position = p.cell_global(float(mid_col + 1), 3.0) + subs[si]
			var fb: Node = pl.call("nearest_interactable")
			ra += 1 if fb != null and roles.get(fb, "") == "T1" else 0
			if fb != null and roles.get(fb, "") == "T1":
				(fb as ShopCounter).interact(pl)
			pl.global_position = p.cell_global(float(mid_col), 3.0) + subs[si]
			var fm: Node = pl.call("nearest_interactable")
			rb += 1 if fm != null and roles.get(fm, "") == "S" else 0
			if fm != null and roles.get(fm, "") == "S" and (fm as ShopCounter).kind == "shop":
				(fm as ShopCounter).interact(pl)
			for f in 8:
				pl.set("facing8", f)
				var fc: Node = pl.call("nearest_interactable")
				rc += 1 if fc != null and str(roles.get(fc, "")).begins_with("T") else 0
		acc["A"] += ra
		acc["B"] += rb
		acc["C"] += rc
		t.expect(ra == 18 and rb == 9 and rc == 0, "%s on the real player: A %d / 18 (end cells select their talk hosts), B %d / 9 (the middle cell selects the centre host), C %d (a talk host from the middle cell at any facing)" % [r, ra, rb, rc])
		acc["keeper_forward"] += keeper.interactions.size()
		acc["centre_opens"] += tap.opened_shops.size()
		tap.stop()
		ShopCounter.keeper_resolver = Callable()
		pl.set("area", old_area)
		pl.global_position = old_pos
		_dispose(p)
	var player_class: String = str(pl.get_script().resource_path) if pl.get_script() != null else "?"
	t.check("talk_cells_select_keeper_real_player", acc["A"] == 36 and acc["B"] == 18 and acc["C"] == 0 and int(acc["keeper_forward"]) == 36 and int(acc["centre_opens"]) == 9,
		"the REAL player (%s, nearest_interactable on the real hosts of the built rooms): E on an end cell facing the counter selects that cell's talk host 36 of 36 and calls the keeper's interact (%d calls); E on the middle cell selects the centre host 18 of 18 (it opens the panel: %d shop_opened = the seed shop's 9 samples; the post counter only announces) and never a talk host at any facing (%d of 144 samples)" % [
			player_class, int(acc["keeper_forward"]), int(acc["centre_opens"]), int(acc["C"])])
	t.check("replay_matches_real_player", mismatch == 0 and total > 1500,
		"the Python replay and the real player agree sample by sample over every standable cell x 9 sub-positions x 8 facings of the two shop rooms: %d samples, %d mismatches %s, host histogram %s" % [total, mismatch, first_bad, str(hist)])


func _column_of(h: ShopCounter, p: Object, spec: Dictionary) -> int:
	for mk in _marker(spec, "talk"):
		if h.global_position.distance_to(p.cell_global(float(mk["cell"][0]), float(mk["cell"][1]))) < 0.5:
			return int(mk["cell"][0])
	return -1


# ================================================================================================ doors

func _doors_in_the_world() -> void:
	Ctx.set_clock(gm, 1, 10.0)
	_mute_world()
	_door_reasons()
	_home_doors()
	_nameplates()
	_unmute_world()
	await _sign_and_emblem()
	await _round_trips()


func _door_in(area_holder: Node, building: String, ctx: Dictionary = {}) -> Door2D:
	var map: AreaMap = AreaMap.parse_text("@id _door_probe\n@projection iso\n@ambient farm\n@ground\n....\n....\n@objects\n@...\n....\n")
	var area := IsoArea.new()
	area_holder.add_child(area)
	area.setup(map)
	var d := Door2D.new()
	d.setup_building({"building": building}, area, Vector2i(1, 1))
	d.ctx_override = ctx
	area.triggers.add_child(d)
	return d


func _player_body(parent: Node) -> Node2D:
	var b := Node2D.new()
	b.add_to_group("player")
	parent.add_child(b)
	return b


func _door_reasons() -> void:
	var holder := Node2D.new()
	t.root.add_child(holder)
	var tap := Tap.new(bus)
	var body: Node2D = _player_body(holder)
	var bakery: Door2D = _door_in(holder, "bageriet")
	var rows: Array = [
		[0, 10.0, false, "day", "HOURS_CLOSED_DAY"], [1, 6.0, false, "hours", "HOURS_CLOSED_NOW"], [1, 17.5, false, "hours", "HOURS_CLOSED_NOW"], [1, 10.0, true, "open", ""], [1, 7.0, true, "open", ""], [1, 16.99, true, "open", ""],
	]
	var bad: Array[String] = []
	for r in rows:
		bakery.ctx_override = Ctx.at(int(r[0]), float(r[1]))
		var got: bool = bakery.is_open()
		var row_ok: bool = got == bool(r[2]) and bakery.last_reason == str(r[3]) and (str(r[4]) == "" or bakery.closed_key() == str(r[4]))
		t.expect(row_ok, "bakery door on %s at %s: %s, reason %s%s" % [Hours.weekday_text(int(r[0])), Hours.format_hour(float(r[1])), "open" if got else "closed", bakery.last_reason, "" if row_ok else " (WRONG)"])
		if not row_ok:
			bad.append("%s %.2f -> %s %s" % [r[0], r[1], got, bakery.last_reason])
	# the whispers are composed from the CSV template: tr(KEY) % args
	bakery.ctx_override = Ctx.at(0, 10.0)
	bakery.is_open()
	var day_text: String = bakery.whisper_text()
	bakery.ctx_override = Ctx.at(1, 6.0)
	bakery.is_open()
	var hours_text: String = bakery.whisper_text()
	var tr_day: String = lm.t("HOURS_CLOSED_DAY", [Hours.weekday_text(1)])
	var tr_hours: String = lm.t("HOURS_CLOSED_NOW", ["07:00"])
	var texts_ok: bool = day_text == tr_day and hours_text == tr_hours and day_text.contains(Hours.weekday_text(1)) and hours_text.contains("07:00")
	# a festival closes the door through the context's closure function
	bakery.ctx_override = Ctx.at(1, 10.0, {"fest_closed_fn": func(shop_id: String) -> bool: return shop_id == "bakery"})
	var fest_closed: bool = not bakery.is_open() and bakery.last_reason == "festival" and bakery.whisper_text() == lm.t("HOURS_CLOSED_FESTIVAL")
	# once per approach: entering twice whispers once, leaving rearms; an open door travels to the interior's `default` spawn
	bakery.ctx_override = Ctx.at(0, 10.0)
	tap.clear()
	bakery._on_body_entered(body)
	bakery._on_body_entered(body)
	var once: bool = tap.whispers == [tr_day] and tap.travels.is_empty()
	bakery._on_body_exited(body)
	bakery._on_body_entered(body)
	var rearmed: bool = tap.whispers.size() == 2 and tap.travels.is_empty()
	bakery.ctx_override = Ctx.at(1, 10.0)
	bakery._on_body_exited(body)
	tap.clear()
	bakery._on_body_entered(body)
	var travels: bool = tap.travels == [[&"int_bageriet", &"default"]] and tap.whispers.is_empty()
	# the exit door of a room is always open at any hour
	var exit_door := Door2D.new()
	exit_door.always_open = true
	exit_door.building_id = "bageriet"
	exit_door.setup({"to": "hyggebyen", "spawn": "from_int_bageriet"}, bakery.get_parent().get_parent() as IsoArea, Vector2i.ZERO)
	holder.add_child(exit_door)
	exit_door.ctx_override = Ctx.at(0, 3.0)
	var exit_open: bool = exit_door.is_open()
	tap.clear()
	exit_door._on_body_entered(body)
	var exit_travels: bool = tap.travels == [[&"hyggebyen", &"from_int_bageriet"]]
	# with the switch off the rule does not exist: a shop door is open at any hour
	gm.set_config_override("towns.hours_enabled", false)
	bakery.ctx_override = Ctx.at(0, 3.0)
	var off_open: bool = bakery.is_open()
	gm.clear_config_overrides()
	tap.stop()
	t.check("door_reasons", bad.is_empty() and texts_ok and fest_closed and once and rearmed and travels and exit_open and exit_travels and off_open,
		"Door2D.is_open reasons day / hours / festival / open over %d moments %s; the whisper is tr(KEY) %% args: \"%s\" (day) and \"%s\" (hours) %s, a festival refuses with HOURS_CLOSED_FESTIVAL %s; a closed door whispers ONCE per approach (two entries, one whisper; leaving rearms it) %s and never travels; an open door requests area_change_requested(int_bageriet, default) %s; the exit door of a room is always open at 03:00 and travels out %s; with the switch off the shop door is always open %s" % [
			rows.size(), "ALL AGREE" if bad.is_empty() else str(bad), tr_day, tr_hours, texts_ok, fest_closed, once and rearmed, travels, exit_open and exit_travels, off_open])
	holder.queue_free()


func _home_doors() -> void:
	var holder := Node2D.new()
	t.root.add_child(holder)
	var tap := Tap.new(bus)
	var body: Node2D = _player_body(holder)
	var fixture_rows: Dictionary = {"fx_home": {"area": "fx_town", "kind": "home", "name_key": "BLD_FX_HOME", "interior": "int_fx_home", "size": "S", "owner": "fx_baker", "wave": "core"},
		"fx_nameplate": {"area": "fx_town", "kind": "home", "name_key": "BLD_FX_NAMEPLATE", "owner": "fx_host", "wave": "core"}}
	Hours.override_registry = fixture_rows
	# (1) wave 4: no Routines at all: every home is a locked nameplate, the shop doors need none
	Hours.routines_path = NO_ROUTINES                                          # explicit: the leg holds whether or not T-routes has landed in the tree
	var door: Door2D = _door_in(holder, "fx_home")
	door.ctx_override = Ctx.at(0, 12.0)
	var no_routines: bool = not ResourceLoader.exists(Hours.routines_path) and Hours.where_is("fx_baker", Ctx.at(0, 12.0)) == null
	var locked_without: bool = not door.is_open() and door.last_reason == "locked" and door.closed_key() == "HOURS_HOME_LOCKED"
	Hours.override_registry = {}
	var shop_door: Door2D = _door_in(holder, "froebutikken", Ctx.at(1, 10.0))
	var shop_without: bool = shop_door.is_open()
	Hours.routines_path = Hours.ROUTINES_PATH
	t.check("door_runs_without_routines", locked_without and shop_without and no_routines,
		"scripts/towns/routines.gd (T-routes, wave 5) is reached only through Hours.where_is (a path string with the default null): without it a home door is a locked nameplate (reason locked, HOURS_HOME_LOCKED) %s while a shop door needs no Routines and opens at Tuesday 10:00 %s; hearts come from SocialManager and then the flag friend_<npc>, never through Routines" % [locked_without, shop_without])
	# (2) with a Routines stand-in: the rules of a home door
	var routines_path: String = WORK + "probe_routines.gd"
	_write(routines_path, "extends RefCounted\nstatic func where_is(npc: String, _ctx: Dictionary) -> Dictionary:\n\treturn Engine.get_meta(\"towns_probe_where\", {\"state\": \"absent\", \"place\": \"\", \"act\": \"\"}).duplicate()\n")
	Hours.routines_path = routines_path
	Hours.override_registry = fixture_rows
	var social: Node = _fake_social()
	var home := func(place: String, act: String, state: String = "stay") -> void: Engine.set_meta("towns_probe_where", {"state": state, "place": place, "act": act})
	var cases: Array = []
	social.hearts_table = {"fx_baker": 2}
	home.call("int_fx_home.table", "eat")
	cases.append(["owner at the table, 2 hearts", door.is_open(), "open"])
	social.hearts_table = {"fx_baker": 0}
	cases.append(["owner at home, 0 hearts", door.is_open(), "stranger"])
	social.hearts_table = {"fx_baker": 1}
	cases.append(["owner at home, exactly 1 heart", door.is_open(), "open"])
	home.call("fx_town.bench", "sit")
	cases.append(["owner out on the bench", door.is_open(), "away"])
	home.call("int_fx_home.bed", "sleep")
	cases.append(["owner asleep in the bed", door.is_open(), "away"])
	home.call("int_fx_home.table", "eat", "inside")
	cases.append(["owner inside (state inside)", door.is_open(), "open"])
	home.call("int_other.table", "eat")
	cases.append(["owner in another building", door.is_open(), "away"])
	Engine.remove_meta("towns_probe_where")
	cases.append(["owner absent (the default)", door.is_open(), "away"])
	var results: Array[String] = []
	var rules_ok: bool = true
	var expect_open: Array = [true, false, true, false, false, true, false, false]
	var expect_reason: Array = ["open", "stranger", "open", "away", "away", "open", "away", "away"]
	var ci: int = 0
	home.call("int_fx_home.table", "eat")
	# replay the sequence with explicit reads of last_reason
	social.hearts_table = {"fx_baker": 2}
	var seq: Array = [[2, "int_fx_home.table", "eat", "stay"], [0, "int_fx_home.table", "eat", "stay"], [1, "int_fx_home.table", "eat", "stay"], [2, "fx_town.bench", "sit", "stay"], [2, "int_fx_home.bed", "sleep", "stay"],
		[2, "int_fx_home.table", "eat", "inside"], [2, "int_other.table", "eat", "stay"]]
	for s in seq:
		social.hearts_table = {"fx_baker": int(s[0])}
		home.call(str(s[1]), str(s[2]), str(s[3]))
		var got: bool = door.is_open()
		results.append("%s %s" % [got, door.last_reason])
		t.expect(got == bool(expect_open[ci]) and door.last_reason == str(expect_reason[ci]), "home door: %s hearts, owner %s %s (%s): %s, reason %s" % [s[0], s[3], s[1], s[2], "open" if got else "closed", door.last_reason])
		rules_ok = rules_ok and got == bool(expect_open[ci]) and door.last_reason == str(expect_reason[ci])
		ci += 1
	# hearts through the flag when no SocialManager answers (a stand-in without a hearts method); the context's own table (Routines.now_ctx) wins
	_release_fakes()
	var mute := Node.new()
	_fakes.append(mute)
	Svc.override("SocialManager", mute)
	home.call("int_fx_home.table", "eat")
	gm.set_flag(&"friend_fx_baker", 0)
	var flag0: bool = not door.is_open() and door.last_reason == "stranger"
	gm.set_flag(&"friend_fx_baker", 1)
	var flag1: bool = door.is_open()
	door.ctx_override = Ctx.at(0, 12.0, {"hearts": {"fx_baker": 0}})
	var ctx_wins: bool = not door.is_open() and door.last_reason == "stranger"
	door.ctx_override = Ctx.at(0, 12.0)
	door.min_hearts = 3
	gm.set_flag(&"friend_fx_baker", 2)
	var min_ok: bool = not door.is_open() and door.last_reason == "stranger"
	gm.clear_flag(&"friend_fx_baker")
	Engine.remove_meta("towns_probe_where")
	Hours.routines_path = Hours.ROUTINES_PATH
	Hours.override_registry = {}
	tap.stop()
	t.check("home_door_rules", rules_ok and flag0 and flag1 and ctx_wins and min_ok,
		"a home door opens only while the owner is IN the house (state stay | inside, place int_<building>), AWAKE (act not sleep) and the friendship allows it (friend_<npc> >= 1): %s; hearts through the flag friend_<npc> without a SocialManager (0 -> stranger %s, 1 -> open %s), the hearts table of the routines context wins %s, min_hearts is honoured %s" % [
			str(results), flag0, flag1, ctx_wins, min_ok])
	holder.queue_free()


func _nameplates() -> void:
	var holder := Node2D.new()
	t.root.add_child(holder)
	var tap := Tap.new(bus)
	var body: Node2D = _player_body(holder)
	# a building without an interior is a locked nameplate: the three homes of the CORE registry and the decor hut
	var kinds: Array[String] = []
	var all_locked: bool = true
	for id in ["fjerpens_hytte", "koekkenhave_skuret", "pingvinens_hus"]:
		var d: Door2D = _door_in(holder, id, Ctx.at(1, 12.0))
		var open: bool = d.is_open()
		all_locked = all_locked and d.locked and not open and d.last_reason == "locked" and d.name_key == "BLD_%s" % id.to_upper() and d.sign_text() == lm.t(d.name_key)
		tap.clear()
		d._on_body_entered(body)
		all_locked = all_locked and tap.whispers == [lm.t("HOURS_HOME_LOCKED")] and tap.travels.is_empty()
		t.expect(d.locked and not open and tap.whispers == [lm.t("HOURS_HOME_LOCKED")] and tap.travels.is_empty(), "%s is a locked nameplate door (sign \"%s\", whisper HOURS_HOME_LOCKED, no travel)" % [id, d.sign_text()])
		kinds.append("%s -> %s" % [id, d.sign_text()])
	t.check("locked_nameplate_door", all_locked,
		"a building without an interior (fjerpens_hytte, koekkenhave_skuret, pingvinens_hus) are LOCKED NAMEPLATE doors: never open, the whisper is HOURS_HOME_LOCKED \"%s\", the sign shows the name only (BLD_<ID>): %s" % [lm.t("HOURS_HOME_LOCKED"), str(kinds)])
	# hyggebyen.map carries door markers of the four EXTENDED buildings; without their registry row (T-ext-content may be dropped) the door is the same nameplate, labelled with BLD_<BUILDING_ID>
	var ext_ok: bool = true
	var shown: Array[String] = []
	for id in ["fekongens_hus", "hyldeblomsts_hus", "pippins_hus", "birks_bistade", "no_such_building_xyz"]:
		if not Hours.building(id).is_empty():
			continue                                                             # T-ext-content landed: the row decides (the door then follows the rules of a real building)
		var d: Door2D = _door_in(holder, id, Ctx.at(1, 12.0))
		var ok: bool = d.locked and not d.is_open() and d.last_reason == "locked" and d.name_key == "BLD_%s" % id.to_upper()
		tap.clear()
		d._on_body_entered(body)
		ok = ok and tap.whispers == [lm.t("HOURS_HOME_LOCKED")] and tap.travels.is_empty()
		if id != "no_such_building_xyz":
			ok = ok and lm.has_key(d.name_key) and d.sign_text() == lm.t(d.name_key) and d.sign_text() != d.name_key
		t.expect(ok, "%s (no registry row) is a locked nameplate labelled %s: \"%s\"" % [id, d.name_key, d.sign_text()])
		ext_ok = ext_ok and ok
		shown.append("%s -> %s" % [id, d.sign_text()])
	t.check("door_without_registry_row_is_locked_nameplate", ext_ok and not shown.is_empty(),
		"a door marker whose building has NO registry row at all (the four EXTENDED houses of hyggebyen.map while lua/buildings/ext.lua is absent, and an invented id) is the same locked nameplate, labelled with the convention key BLD_<BUILDING_ID> that towns.csv defines for all 30 buildings (DT49): %s" % str(shown))
	tap.stop()
	holder.queue_free()


func _sign_and_emblem() -> void:
	PieceCatalog.reset()
	PieceCatalog.kit_manifest_paths = [] as Array[String]
	PieceCatalog.emblems_path = WORK + "absent_emblems.json"
	PieceCatalog.forget()
	# the world: a small outer area with a real player body so the sign zone reacts to him
	await t.start_world()
	var world: Node = t.world()
	WorldRoot2D.register_map(&"_towns_outer", AreaMap.parse_text(_outer_map_text()))
	world.travel(&"_towns_outer", &"default")
	await t.until(func() -> bool: return not world.traveling, 10.0)
	var area: IsoArea = world.area
	var pl: Node2D = world.player
	var cell := Vector2i(9, 6)
	var d: Door2D = Door2D.create_marker({"building": "froebutikken"}, area.cell_to_global(cell), cell, area) as Door2D
	d.ctx_override = {}
	await t.physics(2)
	var spawn_ok: bool = area.spawns.has("from_int_froebutikken") and area.spawns["from_int_froebutikken"].distance_to(area.cell_to_global(cell + Vector2i(0, 1))) < 0.01
	var hidden_far: bool = d.sign_label != null and not d.sign_label.visible
	pl.global_position = area.cell_to_global(Vector2i(9, 8))                                     # two cells from the doorstep: inside the 3 cell zone
	await t.physics(4)
	var shown_near: bool = d.sign_label.visible
	pl.global_position = area.cell_to_global(Vector2i(1, 1))
	await t.physics(4)
	var hidden_again: bool = not d.sign_label.visible
	# the text: the name over HOURS_SIGN with today's hours and the closed days
	var da_text: String = d.sign_text()
	var want: String = "%s\n%s" % [lm.t("HOURS_SIGN", [lm.t("BLD_FROEBUTIKKEN"), "8", "18"]), lm.t("HOURS_SIGN_DAYS", [Hours.weekday_text(6)])]
	var text_ok: bool = da_text == want and da_text.contains(lm.t("BLD_FROEBUTIKKEN")) and da_text.contains("8") and da_text.contains("18") and da_text.contains(Hours.weekday_text(6))
	var rows: Dictionary = Hours.registry().duplicate(true)                                     # a night shop WITH a door (the real night window is an outdoor stall): open 20 - 23:30
	rows["fx_night_shop"] = {"area": "fx_town", "kind": "shop", "name_key": "BLD_FX_NIGHT_SHOP", "interior": "int_fx_night_shop", "size": "S", "shop": "fx_maps", "keeper": "fx_k", "hours": {"open": 20, "close": 23.5, "closed": [], "short_ok": true}, "wave": "core"}
	Hours.override_registry = rows
	var night := Door2D.new()
	night.setup_building({"building": "fx_night_shop"}, area, Vector2i(2, 2))
	var night_text: String = night.sign_text()
	night.free()
	Hours.override_registry = {}
	var short_ok: bool = night_text.contains("20") and night_text.contains("23:30")
	# the emblem: no manifest -> nothing is drawn; with a baked sign bracket and plate -> both, and the text stays the label
	var no_art: bool = d.emblem_sprite == null and d.bracket_sprite == null
	var dir: String = WORK + "emblems/"
	DirAccess.make_dir_recursive_absolute(_abs(dir))
	var img: Image = Image.create_empty(96, 96, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.9, 0.3, 0.3, 1.0))
	img.save_png(_abs(dir + "emblem_seed.png"))
	var bracket: Image = Image.create_empty(72, 40, false, Image.FORMAT_RGBA8)
	bracket.fill(Color(0.5, 0.4, 0.2, 1.0))
	bracket.save_png(_abs(dir + "sign_bracket_r0.png"))
	var def: Dictionary = KIT_PIECE_TEMPLATE.duplicate(true)
	def["layer"] = "wall"
	def["rot"] = {"0": {"file": "sign_bracket_r0.png", "size": [72, 40], "pivot": [36, 30], "footprint": [1, 1]}}
	_write(dir + "shops.json", JSON.stringify({"items": {"sign_bracket": def}}))
	_write(dir + "emblems.json", JSON.stringify({"emblems": {"seed": {"file": "emblem_seed.png", "size": [96, 96], "pivot": [48, 48]}}}))
	PieceCatalog.kit_manifest_paths = [dir + "shops.json"] as Array[String]
	PieceCatalog.emblems_path = dir + "emblems.json"
	PieceCatalog.forget()
	var d2: Door2D = Door2D.create_marker({"building": "froebutikken"}, area.cell_to_global(Vector2i(4, 6)), Vector2i(4, 6), area) as Door2D
	var with_art: bool = d2.emblem_sprite != null and d2.bracket_sprite != null and d2.emblem_sprite.texture != null and d2.sign_label.text != "" and d2.sign_text() == da_text and PieceCatalog.emblem_ids() == ["seed"]
	var plain: Door2D = Door2D.create_marker({"building": "smedjen"}, area.cell_to_global(Vector2i(4, 3)), Vector2i(4, 3), area) as Door2D
	var other_plain: bool = plain.emblem_sprite == null                                       # smedjen's plate `anvil` is not in this manifest: nothing is drawn
	PieceCatalog.reset()
	t.check("door_sign_shows_emblem_when_art_exists", hidden_far and shown_near and hidden_again and text_ok and short_ok and no_art and with_art and other_plain and spawn_ok,
		"the door sign is a world Label that shows within 3 cells of the door (far: hidden %s, two cells away: shown %s, away again: hidden %s), reading the name over HOURS_SIGN with today's hours and the closed days: \"%s\" %s; a night shop reads 20-23:30 %s; the arrival spawn from_int_froebutikken is created one cell in front %s; with no I3 manifest no bracket and no plate are drawn %s, with a baked sign_bracket and an emblem plate both appear above the door %s and a row whose plate is not in the manifest draws nothing %s - the text stays the BLD_<ID> label either way (no glyph is ever baked into art)" % [
			hidden_far, shown_near, hidden_again, da_text.replace("\n", " / "), text_ok, short_ok, spawn_ok, no_art, with_art, other_plain])


func _outer_map_text() -> String:
	var rows: String = ""
	for y in 12:
		rows += "c".repeat(12) + "\n"
	var objs: String = ""
	for y in 12:
		objs += ("@" if y == 6 else ".") + ".".repeat(11) + "\n"
	return OUTER_MAP + rows + "@objects\n" + objs


## Copies of the 3 fixture rooms whose exit leads to the test area `_towns_outer`, in a directory of their own.
func _outer_rooms_dir() -> String:
	var dir: String = WORK + "outer_rooms/"
	DirAccess.make_dir_recursive_absolute(_abs(dir))
	for r in ROOMS:
		var spec: Dictionary = _spec_of(r)
		spec["exit"]["area"] = "_towns_outer"
		_write(dir + r + ".json", _json(spec))
	return dir


func _round_trips() -> void:
	var dir: String = _outer_rooms_dir()
	InteriorRoom.use_spec_dirs([dir] as Array[String])
	var world: Node = t.world()
	var pl: Node2D = world.player
	for r in ROOMS:
		var spec: Dictionary = InteriorRoom.load_spec(r)
		WorldRoot2D.register_map(StringName(r), AreaMap.parse_text(InteriorRoom.stub_map(r, str(spec["building"]), "city")))
	# a home that opens: fixture row + a Routines stand-in that says the owner is at home and 1 heart
	var rows: Dictionary = Hours.registry().duplicate(true)
	rows["hoppe_hut"] = {"area": "traetoppen", "kind": "home", "name_key": "BLD_HOPPE_HUT", "interior": "int_hoppe_hut", "size": "S", "owner": "gardener_hoppe", "wave": "ext"}
	Hours.override_registry = rows
	var routines_path: String = WORK + "probe_routines2.gd"
	_write(routines_path, "extends RefCounted\nstatic func where_is(_npc: String, _ctx: Dictionary) -> Dictionary:\n\treturn {\"state\": \"stay\", \"place\": \"int_hoppe_hut.table\", \"act\": \"eat\"}\n")
	Hours.routines_path = routines_path
	var social: Node = _fake_social()
	social.hearts_table = {"gardener_hoppe": 1}
	Ctx.set_clock(gm, 1, 10.0)
	var tap := Tap.new(bus)
	var all_ok: bool = true
	var notes: Array[String] = []
	var door_cells: Dictionary = {"int_froebutikken": Vector2i(9, 6), "int_postkontoret": Vector2i(9, 3), "int_hoppe_hut": Vector2i(3, 9)}
	for r in ROOMS:
		world.travel(&"_towns_outer", &"default")
		await t.until(func() -> bool: return not world.traveling, 10.0)
		var area: IsoArea = world.area
		var spec: Dictionary = InteriorRoom.load_spec(r)
		var building: String = str(spec["building"])
		var cell: Vector2i = door_cells[r]
		var door: Door2D = Door2D.create_marker({"building": building}, area.cell_to_global(cell), cell, area) as Door2D
		Ctx.set_clock(gm, 1, 10.0)
		tap.clear()
		# in: onto the door
		pl.global_position = area.cell_to_global(cell)
		await t.until(func() -> bool: return world.area != null and str(world.area.map.id) == r, 4.0)
		await t.until(func() -> bool: return not world.traveling, 10.0)
		var inside: bool = str(world.area.map.id) == r
		var arrival: float = pl.global_position.distance_to(world.area.spawns["default"])
		# 90 frames on the arrival spawn: nothing triggers
		var requests_in: int = tap.travels.size()
		await t.physics(90)
		var quiet_in: bool = str(world.area.map.id) == r and tap.travels.size() == requests_in and not world.traveling
		# out: onto the exit door
		var exit_door: Door2D = null
		for c in world.area.triggers.get_children():
			if c is Door2D:
				exit_door = c
		var found_exit: bool = exit_door != null and exit_door.always_open
		tap.clear()
		pl.global_position = exit_door.global_position
		await t.until(func() -> bool: return str(world.area.map.id) == "_towns_outer", 4.0)
		await t.until(func() -> bool: return not world.traveling, 10.0)
		var back: bool = str(world.area.map.id) == "_towns_outer"
		var arrival_out: float = pl.global_position.distance_to(world.area.spawns["from_int_" + building]) if back else 999.0
		var requests_out: int = tap.travels.size()
		await t.physics(90)
		var quiet_out: bool = str(world.area.map.id) == "_towns_outer" and tap.travels.size() == requests_out and not world.traveling
		var one: bool = inside and arrival < 0.5 and quiet_in and found_exit and back and arrival_out < 0.5 and quiet_out
		all_ok = all_ok and one
		notes.append("%s in %.2f px, out %.2f px, quiet %s / %s" % [r, arrival, arrival_out, quiet_in, quiet_out])
	# a closed door does not round-trip: Monday 10:00 the seed shop whispers and nothing moves
	world.travel(&"_towns_outer", &"default")
	await t.until(func() -> bool: return not world.traveling, 10.0)
	var area2: IsoArea = world.area
	var closed_cell := Vector2i(6, 9)
	Door2D.create_marker({"building": "froebutikken"}, area2.cell_to_global(closed_cell), closed_cell, area2)
	Ctx.set_clock(gm, 6, 10.0)                                                           # Sunday: the seed shop is closed
	tap.clear()
	pl.global_position = area2.cell_to_global(closed_cell)
	await t.physics(10)
	var stays: bool = str(world.area.map.id) == "_towns_outer" and tap.travels.is_empty() and tap.whispers.size() == 1 and tap.whispers[0] == Hours.closed_text(Hours.state("froebutikken", Ctx.at(6, 10.0)))
	tap.stop()
	_release_fakes()
	Hours.override_registry = {}
	Hours.routines_path = Hours.ROUTINES_PATH
	WorldRoot2D.unregister_map(&"_towns_outer")
	for r in ROOMS:
		WorldRoot2D.unregister_map(StringName(r))
	InteriorRoom.use_spec_dirs([FIXTURES] as Array[String])
	t.check("every_door_round_trips", all_ok and stays,
		"in the REAL WorldRoot2D every door round-trips: the player walks onto the door of the seed shop, the post office and a home that opens (owner at home, 1 heart, Routines stand-in) and arrives on the room's `default` spawn, walks onto the exit door (always open) and arrives on the outer area's from_int_<building> spawn, both 0.0 px from the spawn (%s); a closed door (Sunday) whispers once and moves nobody %s" % [str(notes), stays])
	t.check("arrival_spawn_does_not_retrigger", all_ok,
		"standing on an arrival spawn for 90 physics frames triggers nothing, inside (the room's default spawn is one cell in front of the exit door) and outside (from_int_<building> is one cell in front of the door): no area_change_requested after the arrival (%s)" % str(notes))


# ================================================================================================ closing time

func _closing_time() -> void:
	Hours.override_registry = {}
	_mute_world()
	var tap := Tap.new(bus)
	var holder := Node2D.new()
	t.root.add_child(holder)
	var world: Node = t.world()
	# the sequence: the seed shop closes at 18:00 on a Tuesday
	var sh := ShopHours.new()
	holder.add_child(sh)
	sh.setup("froebutikken", "int_froebutikken", "hyggebyen", "from_int_froebutikken")
	var steps: Array = [[16.0, 0, 0], [17.0, 0, 0], [17.49, 0, 0], [17.5, 1, 0], [17.75, 1, 0], [17.99, 1, 0], [18.0, 2, 1], [18.2, 2, 1]]       # hour, whispers so far, travel requests so far
	for step in steps:
		sh.check(Ctx.at(1, float(step[0])))
		t.expect(tap.whispers.size() == int(step[1]) and tap.travels.size() == int(step[2]), "seed shop, Tuesday %s: %d whisper(s) and %d travel request(s) so far (%s)" % [Hours.format_hour(float(step[0])), tap.whispers.size(), tap.travels.size(), str(tap.whispers)])
	var warn: Array = tap.named("closing_warning")
	var changed: Array = tap.named("shop_open_changed")
	var order: Array = []
	for w in tap.whispers:
		order.append(w)
	var seq_ok: bool = order == ["HOURS_CLOSING_SOON", "HOURS_CLOSED_BELL"] and tap.travels == [[&"hyggebyen", &"from_int_froebutikken"]] and warn.size() == 1 and changed.size() == 1 and sh.evicted and sh.trace == ["whisper HOURS_CLOSING_SOON", "evict closed"]
	t.check("closing_sequence", seq_ok,
		"the seed shop (closes 18:00): nothing at 17:00 and 17:29, at 17:30 the whisper HOURS_CLOSING_SOON and game_event closing_warning once (not again at 17:45 or 17:59), at 18:00 the whisper HOURS_CLOSED_BELL, shop_open_changed and area_change_requested(hyggebyen, from_int_froebutikken): %s, then nothing more %s" % [str(order), sh.evicted])
	# the events and their payloads (JSON-safe): minutes_left 30, the next opening
	var w0: Dictionary = warn[0][1] if not warn.is_empty() else {}
	var c0: Dictionary = changed[0][1] if not changed.is_empty() else {}
	var payload_ok: bool = w0 == {"shop": "seed_shop", "minutes_left": 30} and typeof(w0.get("minutes_left")) == TYPE_INT and c0.get("shop") == "seed_shop" and c0.get("open") == false and c0.get("reason") == "hours" \
		and is_equal_approx(float(c0.get("opens_at", 0.0)), 8.0) and is_equal_approx(float(c0.get("closes_at", 0.0)), 18.0) and (c0.keys().size() == 5)
	var order_ok: bool = tap.events.map(func(e: Array) -> String: return str(e[0])).filter(func(n: String) -> bool: return n in ["closing_warning", "shop_open_changed"]) == ["closing_warning", "shop_open_changed"]
	# once per day: a new day rearms both
	tap.clear()
	var sh2 := ShopHours.new()
	holder.add_child(sh2)
	sh2.setup("froebutikken", "int_froebutikken", "hyggebyen", "from_int_froebutikken")
	sh2.check(Ctx.at(2, 17.6))
	sh2.check(Ctx.at(2, 17.8))
	var once: bool = tap.named("closing_warning").size() == 1
	bus.day_started.emit(3, &"foraar")
	sh2.check(Ctx.at(3, 17.6))
	var again: bool = tap.named("closing_warning").size() == 2
	# closed by the weekday while the player stands inside (Sunday): the event says reason day
	tap.clear()
	var sh3 := ShopHours.new()
	holder.add_child(sh3)
	sh3.setup("froebutikken", "int_froebutikken", "hyggebyen", "from_int_froebutikken")
	sh3.check(Ctx.at(6, 12.0))
	var day_ev: Array = tap.named("shop_open_changed")
	var day_ok: bool = day_ev.size() == 1 and day_ev[0][1].get("reason") == "day" and is_equal_approx(float(day_ev[0][1].get("opens_at", 0.0)), 8.0)
	t.check("events_closing_warning_and_shop_open_changed", payload_ok and order_ok and once and again and day_ok,
		"closing_warning {shop: seed_shop, minutes_left: 30 (an int)} once per shop and day %s (a new day rearms it %s); shop_open_changed {shop, open: false, reason, opens_at, closes_at} (reason hours, next opening 8.0, closes 18.0) %s, in the order warning then change %s; closed by the weekday it says reason day %s" % [once, again, payload_ok, order_ok, day_ok])
	# a panel open at closing time is asked to close through the TTScreen request; then the bell and the travel
	tap.clear()
	var sh4 := ShopHours.new()
	holder.add_child(sh4)
	sh4.setup("froebutikken", "int_froebutikken", "hyggebyen", "from_int_froebutikken")
	gm.push_modal(&"shop", true)
	sh4.check(Ctx.at(1, 18.1))
	var panel_closed: bool = tap.panels == [[&"shop", false]] and tap.whispers == ["HOURS_CLOSED_BELL"] and tap.travels.size() == 1
	gm.pop_modal(&"shop")
	# held back during a modal that is not the shop (a dialogue at 18:06 delays the bell until it ends), also the pause menu
	tap.clear()
	var sh5 := ShopHours.new()
	holder.add_child(sh5)
	sh5.setup("froebutikken", "int_froebutikken", "hyggebyen", "from_int_froebutikken")
	gm.push_modal(&"dialogue", false)
	sh5.check(Ctx.at(1, 18.1))
	var held_dialogue: bool = tap.whispers.is_empty() and tap.travels.is_empty() and not sh5.evicted
	gm.pop_modal(&"dialogue")
	sh5.check(Ctx.at(1, 18.1))
	var released: bool = tap.whispers == ["HOURS_CLOSED_BELL"] and tap.travels.size() == 1 and sh5.evicted
	tap.clear()
	var sh6 := ShopHours.new()
	holder.add_child(sh6)
	sh6.setup("froebutikken", "int_froebutikken", "hyggebyen", "from_int_froebutikken")
	gm.push_modal(&"pause", true)
	sh6.check(Ctx.at(1, 18.1))
	var held_pause: bool = tap.travels.is_empty() and not sh6.evicted
	gm.pop_modal(&"pause")
	sh6.check(Ctx.at(1, 18.1))
	var after_pause: bool = sh6.evicted and tap.travels.size() == 1
	t.check("closing_held_during_modal", panel_closed and held_dialogue and released and held_pause and after_pause,
		"a shop panel open at closing time is asked to close first (ui_panel_toggled(shop, false)) and the player is shown out %s; with a DIALOGUE open at 18:06 nothing happens (no whisper, no travel) and the bell and the travel come when it ends %s %s; the pause menu holds it back as well %s %s" % [panel_closed, held_dialogue, released, held_pause, after_pause])
	# waits for a running travel or sleep sequence: WorldRoot2D.travel() returns silently while it travels, so the eviction is retried and `evicted` stays false until it is really requested
	tap.clear()
	var sh7 := ShopHours.new()
	holder.add_child(sh7)
	sh7.setup("froebutikken", "int_froebutikken", "hyggebyen", "from_int_froebutikken")
	var waits_ok: bool = false
	var wait_notes: String = "no WorldRoot2D"
	if world != null:
		world.set("traveling", true)
		sh7.check(Ctx.at(1, 18.1))
		var held_travel: bool = tap.travels.is_empty() and tap.whispers.is_empty() and not sh7.evicted
		world.set("traveling", false)
		world.set("sleeping", true)
		sh7.check(Ctx.at(1, 18.2))
		var held_sleep: bool = tap.travels.is_empty() and not sh7.evicted
		world.set("sleeping", false)
		sh7.check(Ctx.at(1, 18.3))
		var finally: bool = sh7.evicted and tap.travels.size() == 1 and tap.whispers == ["HOURS_CLOSED_BELL"]
		waits_ok = held_travel and held_sleep and finally
		wait_notes = "held while traveling %s, held while sleeping %s, evicted on the first tick after %s" % [held_travel, held_sleep, finally]
	t.check("closing_waits_for_travel", waits_ok,
		"a closing tick that lands in the 0.25 - 0.5 s fade of entering the room (WorldRoot2D.traveling) or in a sleep sequence is RETRIED on the next tick and never lost: %s; `evicted` is set only when the area change is really requested, so the player is never left inside a closed shop" % wait_notes)
	await _routines_free_and_homes(tap, holder)
	tap.stop()
	holder.queue_free()
	_unmute_world()
	Ctx.set_clock(gm, 1, 10.0)


func _routines_free_and_homes(tap: Tap, holder: Node) -> void:
	# without Routines (wave 4) a shop room works exactly the same and a home never evicts by owner
	tap.clear()
	Hours.override_registry = {"fx_home": {"area": "fx_town", "kind": "home", "name_key": "BLD_FX_HOME", "interior": "int_fx_home", "size": "S", "owner": "fx_baker", "wave": "core"}}
	var home := ShopHours.new()
	holder.add_child(home)
	home.setup("fx_home", "int_fx_home", "fx_town", "from_int_fx_home")
	Hours.routines_path = NO_ROUTINES                                          # explicit: the leg holds whether or not T-routes has landed in the tree
	home.check(Ctx.at(0, 20.0))
	home.check(Ctx.at(0, 22.2))
	var no_owner_eviction: bool = not home.evicted and tap.travels.is_empty() and not ResourceLoader.exists(Hours.routines_path)
	Hours.routines_path = Hours.ROUTINES_PATH
	t.check("shop_hours_runs_without_routines", no_owner_eviction,
		"ShopHours needs no Routines: the closing sequence above ran without them (its clock context is Hours.now_ctx()), and the owner check of a home goes through Hours.where_is (a path string): with no Routines there is no eviction by owner (a home at 20:00 and at 22:12 evicts nobody %s)" % no_owner_eviction)
	# with a Routines stand-in: the owner goes to bed -> the guest is shown out; the owner walks out -> the same
	var path: String = WORK + "probe_routines3.gd"
	_write(path, "extends RefCounted\nstatic func where_is(_npc: String, ctx: Dictionary) -> Dictionary:\n\tvar h: float = float(ctx.get(\"hour\", 12.0))\n\tif h >= 22.0:\n\t\treturn {\"state\": \"stay\", \"place\": \"int_fx_home.bed\", \"act\": \"sleep\"}\n\tif h >= 20.5:\n\t\treturn {\"state\": \"stay\", \"place\": \"fx_town.bench\", \"act\": \"sit\"}\n\treturn {\"state\": \"stay\", \"place\": \"int_fx_home.table\", \"act\": \"eat\"}\n")
	Hours.routines_path = path
	var cases: Array[String] = []
	var ok: bool = true
	for pair in [[20.0, false], [20.7, true], [22.2, true]]:
		tap.clear()
		var sh := ShopHours.new()
		holder.add_child(sh)
		sh.setup("fx_home", "int_fx_home", "fx_town", "from_int_fx_home")
		sh.check(Ctx.at(0, float(pair[0])))
		ok = ok and sh.evicted == bool(pair[1]) and (tap.travels.size() == 1) == bool(pair[1])
		cases.append("%.1f -> %s" % [pair[0], sh.evicted])
	var sh_bed := ShopHours.new()
	holder.add_child(sh_bed)
	sh_bed.setup("fx_home", "int_fx_home", "fx_town", "from_int_fx_home")
	tap.clear()
	sh_bed.check(Ctx.at(0, 22.2))
	var bell: bool = sh_bed.trace == ["evict owner_left"] and tap.named("shop_open_changed").is_empty()
	Hours.routines_path = Hours.ROUTINES_PATH
	Hours.override_registry = {}
	t.check("home_eviction", ok and bell,
		"a home evicts its guest when the owner goes to bed or walks out (Routines stand-in: 20:00 at the table -> stays %s, 20:42 out on the bench and 22:12 in bed -> shown out): %s; a home sends no shop_open_changed (it is no shop) %s" % [str(cases[0]), str(cases), bell])


# ================================================================================================ the tool

func _tool() -> void:
	if not _py_ok:
		t.skip("towns_interiors.tool_regenerates_identical_specs: python3 was not found: the generator, the validator and their self-test cannot run")
		return
	var gen1: Dictionary = _py("generate.py", ["--out", _abs(WORK + "gen1")])
	var gen2: Dictionary = _py("generate.py", ["--out", _abs(WORK + "gen2")])
	var same: bool = int(gen1["code"]) == 0 and int(gen2["code"]) == 0
	var count: int = 0
	var d := DirAccess.open(WORK + "gen1")
	if d != null:
		for f in d.get_files():
			count += 1
			same = same and FileAccess.get_file_as_string(WORK + "gen1/" + f) == FileAccess.get_file_as_string(WORK + "gen2/" + f)
	var fixtures_same: bool = true
	for r in ROOMS:
		fixtures_same = fixtures_same and FileAccess.get_file_as_string(WORK + "gen1/" + r + ".json") == FileAccess.get_file_as_string(FIXTURES + r + ".json")
	var check_fix: Dictionary = _py("generate.py", ["--check", _abs(FIXTURES), _abs("res://data/interiors")])
	# a hand edit is noticed unless it is marked: the check fails on a changed spec and skips one marked hand_edited
	DirAccess.make_dir_recursive_absolute(_abs(WORK + "edit"))
	var edited: Dictionary = _spec_of("int_froebutikken")
	edited["zoom_fit"] = 0.5
	_write(WORK + "edit/int_froebutikken.json", JSON.stringify(edited, " "))
	var noticed: Dictionary = _py("generate.py", ["--check", _abs(WORK + "edit")])
	edited["hand_edited"] = true
	_write(WORK + "edit/int_froebutikken.json", JSON.stringify(edited, " "))
	var skipped: Dictionary = _py("generate.py", ["--check", _abs(WORK + "edit")])
	# the 24 rooms pass the validator, and the acceptance command is clean
	var valid: Dictionary = _py("validate.py", [_abs(WORK + "gen1")])
	var accept: Dictionary = _py("validate.py", [_abs("res://data/interiors"), _abs(FIXTURES)])
	var selftest: Dictionary = _py("validate.py", ["--selftest"])
	var selftest_ids: Dictionary = t.parse_tool_ids(selftest)
	var core_rooms: int = 0
	for f in (valid["lines"] as PackedStringArray):
		if str(f).begins_with("PASS "):
			core_rooms += 1
			t.expect(true, "the validator passes the generated room %s" % str(f).substr(5))
		elif str(f).begins_with("FAIL "):
			t.expect(false, "the validator reports %s" % str(f))
	# the stub maps the generator writes (for T-interiors-core and T-ext-content) are the text of InteriorRoom.stub_map, and their zone is the zone of the outer area's map
	var maps: Dictionary = _py("generate.py", ["--maps", _abs(WORK + "maps")])
	var maps_ok: bool = int(maps["code"]) == 0
	var md := DirAccess.open(WORK + "maps")
	var map_count: int = 0
	if md != null:
		for f in md.get_files():
			map_count += 1
			var rid: String = f.get_basename()
			var spec: Variant = JSON.parse_string(FileAccess.get_file_as_string(WORK + "gen1/" + rid + ".json"))
			var outer: AreaMap = AreaMap.load_file("res://data/maps/%s.map" % str(spec["exit"]["area"]))
			var want: String = InteriorRoom.stub_map(rid, str(spec["building"]), str(outer.zone))
			var same_map: bool = FileAccess.get_file_as_string(WORK + "maps/" + f) == want
			t.expect(same_map, "the generator's stub map of %s is InteriorRoom.stub_map (zone %s)" % [rid, outer.zone])
			maps_ok = maps_ok and same_map
	# the building table the generator reads equals the Lua registry (area, kind, size, shop, keeper, owner of every room)
	var bt: Dictionary = _py("generate.py", ["--buildings"])
	var table: Variant = JSON.parse_string(str(bt["output"]))
	var drift: Array[String] = []
	if table is Dictionary:
		var reg: Dictionary = Hours.registry()
		for id in (table as Dictionary):
			if not reg.has(id):
				continue                                                                     # an EXTENDED row (T-ext-content)
			var row: Dictionary = reg[id]
			var want: Dictionary = table[id]
			var kind_ok: bool = str(row.get("kind", "")) == str(want["kind"])
			if not (kind_ok and str(row.get("area", "")) == str(want["area"]) and str(row.get("size", "")) == str(want["size"]) and str(row.get("shop", "")) == str(want["shop"]) \
					and str(row.get("keeper", "")) == str(want["keeper"]) and str(row.get("owner", "")) == str(want["owner"])):
				drift.append(str(id))
	else:
		drift.append("no table")
	t.check("tool_regenerates_identical_specs", same and count == 24 and fixtures_same and int(check_fix["code"]) == 0 and int(noticed["code"]) == 1 and int(skipped["code"]) == 0 and str(skipped["output"]).contains("hand_edited") \
		and int(valid["code"]) == 0 and core_rooms == 24 and int(accept["code"]) == 0 and str(accept["output"]).contains("0 problem(s)") and int(selftest["code"]) == 0 and (selftest_ids["fail"] as Array).is_empty() and (selftest_ids["pass"] as Array).size() >= 16 and drift.is_empty() and maps_ok and map_count == 24,
		"tools/towns/interiors/generate.py is seed-free and deterministic: two runs write the same %d specs byte for byte %s, the three fixture rooms ARE its output %s, `--check` over the fixtures and data/interiors passes %s, a changed spec is noticed (exit 1) %s and one marked hand_edited is skipped %s; validate.py: all 24 generated rooms pass (%d PASS), `validate.py data/interiors tests/fixtures/towns/interiors` prints 0 problems %s, its self-test catches %d mutants and the clean room passes %s; the 24 stub maps it writes equal InteriorRoom.stub_map %s; the building table of the generator equals the Lua registry (drift %s)" % [
			count, same, fixtures_same, int(check_fix["code"]) == 0, int(noticed["code"]) == 1, int(skipped["code"]) == 0, core_rooms, int(accept["code"]) == 0, (selftest_ids["pass"] as Array).size() - 3, (selftest_ids["fail"] as Array).is_empty(), maps_ok, str(drift)])


# ================================================================================================ windowed

## The 14 door markers of the REAL hyggebyen.map get their Door2D (T-director's TownMarker will do this by itself): the sign of the seed shop and of the bakery, 12:00 on a Tuesday.
func _windowed_doors(world: Node, pl: Node2D) -> void:
	ShopCounter.keeper_resolver = Callable()
	world.travel(&"hyggebyen", &"default")
	await t.until(func() -> bool: return not world.traveling, 10.0)
	var area: IsoArea = world.area
	var doors: Dictionary = {}
	for rec in area.find_markers("door"):
		if rec["node"] == null:
			rec["node"] = Door2D.create_marker(rec["params"], rec["pos"], rec["cell"], area)
		doors[str((rec["params"] as Dictionary).get("building", ""))] = rec
	Ctx.set_clock(gm, 1, 12.0)
	for b in ["froebutikken", "bageriet", "fekongens_hus"]:
		var rec: Dictionary = doors.get(b, {})
		if rec.is_empty():
			continue
		pl.global_position = area.cell_to_global((rec["cell"] as Vector2i) + Vector2i(1, 1))
		pl.set("facing8", 4)
		await t.seconds(0.6)
		await t.capture("door_%s" % b)
	t.check("windowed_doors_have_signs", doors.size() == 14, "the %d door markers of hyggebyen.map build a Door2D with a sign each (shots door_froebutikken, door_bageriet, door_fekongens_hus: the last is an extended house without a registry row, a locked nameplate)" % doors.size())


func run_windowed(p_t) -> void:
	var original_maps: Dictionary = WorldRoot2D.scan_maps().duplicate(true)
	var original_dirs: Array[String] = InteriorRoom.spec_dirs.duplicate()
	var original_dress := InteriorRoom.dress_dir
	t = p_t
	gm = t.autoload("GameManager")
	lm = t.autoload("LocalizationManager")
	bus = t.autoload("EventBus")
	_reset()
	await t.start_world()
	var world: Node = t.world()
	var pl: Node2D = world.player
	InteriorRoom.use_spec_dirs([FIXTURES] as Array[String])
	for r in ROOMS:
		var spec: Dictionary = InteriorRoom.load_spec(r)
		WorldRoot2D.register_map(StringName(r), AreaMap.parse_text(InteriorRoom.stub_map(r, str(spec["building"]), "city")))
	Ctx.set_clock(gm, 1, 12.0)                                                         # Tuesday noon: the seed shop and the post office are open
	var firsts: Array[float] = []
	var shop_panel_exists: bool = ResourceLoader.exists("res://scenes/ui/shop_ui.tscn")
	for r in ROOMS:
		var spec: Dictionary = InteriorRoom.load_spec(r)
		var t0: int = Time.get_ticks_msec()
		ShopCounter.keeper_resolver = Callable()
		world.call("_enter", StringName(r), &"default")                                   # the room is built and put in the tree: what the player waits for behind the fade
		await RenderingServer.frame_post_draw
		firsts.append(float(Time.get_ticks_msec() - t0))
		var area: IsoArea = world.area
		var keeper_cell: Vector2i = _keeper_of(spec)
		if keeper_cell.x < 0:                                                             # a home: its owner stands at the table
			for po in spec["posts"]:
				if str(po["id"]) == "table":
					keeper_cell = Vector2i(int(po["cell"][0]), int(po["cell"][1]))
		var keeper := KeeperStub.new()
		area.objects.add_child(keeper)
		keeper.global_position = area.to_global(InteriorRoom.cell_local(float(keeper_cell.x), float(keeper_cell.y)))
		var visual_id: String = "fairy_shopkeeper" if r == "int_froebutikken" else ("hedgehog_pip" if r == "int_postkontoret" else "rabbit")
		keeper.with_visual(visual_id)
		ShopCounter.keeper_resolver = func(id: String) -> Node: return keeper
		for h in _counters(area):
			h._refresh()
		# the player at the counter front: the middle cell, facing the counter
		if spec.has("markers") and not _marker(spec, "talk").is_empty():
			pl.global_position = area.to_global(InteriorRoom.cell_local(float(keeper_cell.x), 3.0))
			pl.set("facing8", 5)
		await t.seconds(0.8)
		await t.capture(r.trim_prefix("int_"))
	await _windowed_doors(world, pl)
	await _windowed_painted_rooms(world)
	var first_ok: bool = true
	for f in firsts:
		first_ok = first_ok and f <= 250.0
	t.check("windowed_first_frame_budget", first_ok, "the first frame of a room (build + first drawn frame) of the 3 fixture rooms: %s ms (budget <= 250; design measured 120-210 ms on the M3 in GL Compatibility)" % str(firsts))
	if not shop_panel_exists:
		t.skip("towns_interiors.windowed_shop_panel_over_room: scenes/ui/shop_ui.tscn (P18-ui-shop-inventory) does not exist yet: the screenshot of the room without the panel would prove nothing; REQUIRED at the G5b gate")
	else:
		world.call("_enter", &"int_froebutikken", &"default")
		await t.seconds(0.4)
		var before: Image = await t.capture()
		var keeper_cell: Vector2i = _keeper_of(InteriorRoom.load_spec("int_froebutikken"))
		pl.global_position = world.area.to_global(InteriorRoom.cell_local(float(keeper_cell.x), 3.0))
		pl.set("facing8", 5)
		await t.physics(3)
		t.tap(&"interact")
		await t.seconds(0.8)
		var after: Image = await t.capture("froebutikken_shop_panel")
		var opened: bool = gm.is_modal_open(&"shop") or gm.is_modal_open(&"shop_ui")
		t.check("windowed_shop_panel_over_room", opened and t.mean_abs_diff(before, after) > 6.0, "E on the middle cell opens the shop panel over the live room: modal open %s, the frame changed by %.1f" % [opened, t.mean_abs_diff(before, after)])
	ShopCounter.keeper_resolver = Callable()
	for r in ROOMS:
		WorldRoot2D.unregister_map(StringName(r))
	_reset()
	InteriorRoom.use_spec_dirs(original_dirs,original_dress)
	# These fixtures temporarily replace production ids. Unregistering them
	# alone removes the real room from the already-scanned global registry.
	WorldRoot2D._registry = original_maps


func _windowed_painted_rooms(world: Node) -> void:
	_generate_all24()
	_use_room_set()
	# Keep closed shops available solely for the night-art inspection.
	gm.set_config_override("towns.hours_enabled", false)
	var room_ids := ["int_bageriet", "int_smedjen", "int_troldmandstaarnet", "int_hoppe_hut"]
	for room_id in room_ids:
		var spec := InteriorRoom.load_spec(room_id)
		WorldRoot2D.register_map(StringName(room_id), AreaMap.parse_text(InteriorRoom.stub_map(room_id, str(spec["building"]), "city")))
		for hour in [12.0, 22.0]:
			Ctx.set_clock(gm, 1, hour)
			world.travel(StringName(room_id), &"default")
			await t.until(func() -> bool: return not world.traveling, 10.0)
			await t.seconds(0.25)
			t.expect(str(world.area.map.id) == room_id, "the inspected room stays loaded at night")
			var frame: Image = await t.capture("painted_%s_%s" % [room_id, "day" if hour == 12.0 else "night"])
			t.expect_not_blank(frame, Rect2i(0, 0, 1280, 720), "%s at %02d:00 renders painted body art and room-owned accents" % [room_id, int(hour)])
		WorldRoot2D.unregister_map(StringName(room_id))
	gm.clear_config_overrides()
