class_name WorldRoot2D
extends Node2D
## Persistent game root (scenes/main/world.tscn, group `world_2d`). Owns everything that must survive an area switch: the player, the
## FarmGrid model (when P06 has landed), the GameUI (P07), the day / night tint, the rain overlay and the fade. Areas (IsoArea) are
## swapped in and out of AreaHolder; the player is reparented into the new area's y-sorted Objects.
##
##   World (WorldRoot2D)
##   |- AreaHolder (Node2D)       the current IsoArea (iso areas without a builder are PARKED in a cache when left, the rest rebuilt)
##   |- FarmGrid (Node)           crop model, always alive (res://scripts/world2d/farm_grid.gd, P06; absent until then)
##   |- DayNight (CanvasModulate) the one CanvasModulate of the canvas
##   |- Player                    parked here between two areas; lives in area.Objects otherwise
##   |- GameUI (CanvasLayer 10)   scenes/ui/game_ui.tscn (P07); set_mode(&"farm" | &"action") on every travel
##   |- WeatherFx (CanvasLayer 6) rain overlay      |- Vignette (CanvasLayer 5, dark areas)      |- FadeLayer (CanvasLayer 100)
##
## AREA REGISTRY: res://data/maps/*.map, id from `@id` (files starting with `_` are fixtures: _fixture_iso, _fixture_ortho).
## The default start area is `farm` when data/maps/farm.map exists, else `_fixture_iso` (so the player / HUD tests run before P11).
## BUILDER ROOMS (the home interior): never parked, rebuilt on every enter and on EventBus.home_upgraded / furniture_changed (placed |
## removed | tier | load). While a travel or the night runs (`traveling`) the request is only QUEUED and runs behind the black screen: at the
## end of the sleep sequence's night (before the fade-in) and at the end of a travel; _enter() clears it (the room it builds is current).
## ZONES: EventBus.zone_entered(zone) is emitted ONLY here (zone id = the map's @zone, else lua/config/ambient.lua area_zone), and
## zones unlock through GameManager.unlock_zone. Pass-out: EventBus.game_event(&"midnight_passed") (P02); wake up with
## GameManager.sleep_until_morning().

signal area_ready(area_id: StringName)
## The saved world state (placed items, area flags, crops, hotbar) has been applied: after a Continue / load in _ready, and on from_dict.
## The area is entered BEFORE the state arrives, and EventBus.load_completed fired before the world scene even existed, so world-owned
## scenery that reads area flags (the greenhouse) redraws on this signal.
signal state_applied

const MAP_DIR := "res://data/maps/"
const PLAYER_SCENE_PATH := "res://scenes/world2d/player_2d.tscn"
const GAME_UI_PATH := "res://scenes/ui/game_ui.tscn"
const FARM_GRID_PATH := "res://scripts/world2d/farm_grid.gd"
const FARM_VIEW_PATH := "res://scripts/world2d/farm_view.gd"
const INTRO_PATH := "res://scripts/world2d/intro_sequence.gd"
const INTRO_ENTRY_POINTS: Array[String] = ["run", "start", "play"]
const DEFAULT_AREA := &"farm"
const FALLBACK_AREA := &"_fixture_iso"
## Clips whose sheets are warmed behind the fade (the player keeps these resident; NPCs only the idle / talk / hover ones).
const PLAYER_WARM_CLIPS: Array[String] = ["idle", "walk", "run", "interact", "talk"]
const NPC_WARM_CLIPS: Array[String] = ["idle", "talk", "hover"]
## Rooms that change with the home tier or the furniture are rebuilt when one of these furniture_changed reasons arrives.
const REBUILD_REASONS: Array[StringName] = [&"placed", &"removed", &"tier", &"load"]
const FADE_OUT := 0.22
const FADE_IN := 0.25

var player: Node2D
var farm: Node
var greenhouse_farm: FarmGrid
var area: IsoArea
var game_ui: Node
var day_night: DayNight
var weather_fx: WeatherFx
var holder: Node2D
var traveling: bool = false
var sleeping: bool = false
var _pass_out_pending: bool = false
## Items placed in the world by PlacementService (P20): [{item, cell}], saved by to_dict().
var placed_items: Array = []
## Placed records of a save whose item this build cannot place (content drift): kept in the save, adopted again when it can.
var placed_orphans: Array = []
## Per-area JSON-safe flags: area id -> {key: value} (opened chests, picked nodes ...), saved by to_dict().
var area_flags: Dictionary = {}
var last_travel_error: String = ""
## Tests / tools: also warm the sprite clips under the dummy renderer (see warm_clips()).
var warm_in_headless: bool = false
## The opening-hook script (a test can point it at its own file or hand over a Script object).
var intro_script_path: String = INTRO_PATH
var intro_script: Script = null
var warm_skipped: int = 0
var ready_for_play := false
var last_travel_profile: Dictionary = {}
var art_prefetch: AreaArtPrefetch

var _cache: Dictionary = {}                 # area id -> parked IsoArea
var _fade: ColorRect
var _vignette: CanvasLayer
var _vignette_rect: TextureRect
var _faint_pending: bool = false
var _zone: StringName = &""
var _rebuild_queued: bool = false

static var _registry: Dictionary = {}       # id -> {path, fixture, map: AreaMap or null (in-memory maps of tests)}
static var _registry_scanned: bool = false


# ------------------------------------------------------------------ the area registry (static)

## Scans res://data/maps/*.map once: id -> {path, fixture: bool}. In-memory maps registered with register_map() stay.
static func scan_maps(force: bool = false) -> Dictionary:
	if _registry_scanned and not force:
		return _registry
	for id in _registry.keys():
		if _registry[id].get("map", null) == null:
			_registry.erase(id)
	var dir := DirAccess.open(MAP_DIR)
	if dir != null:
		var files: Array[String] = []
		for f in dir.get_files():
			if f.ends_with(".map"):
				files.append(f)
		files.sort()
		for f in files:
			var path: String = MAP_DIR + f
			var id: String = _header_id(path)
			if id == "":
				id = f.get_basename()
			if not _registry.has(StringName(id)):
				_registry[StringName(id)] = {"path": path, "fixture": f.begins_with("_"), "map": null}
	_registry_scanned = true
	return _registry


static func _header_id(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	while not f.eof_reached():
		var line: String = f.get_line().strip_edges()
		if line.begins_with("@id "):
			return line.substr(4).strip_edges()
		if line.begins_with("@ground") or line.begins_with("@objects"):
			break
	return ""


## Area ids of the registry (fixtures only when asked), sorted.
static func area_ids(include_fixtures: bool = false) -> Array[StringName]:
	var out: Array[StringName] = []
	var reg: Dictionary = scan_maps()
	for id in reg:
		if include_fixtures or not bool(reg[id]["fixture"]):
			out.append(id)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


static func has_area(id: StringName) -> bool:
	return scan_maps().has(id)


## The id a new game starts in: `farm` when its map exists, else `_fixture_iso`.
static func default_area_id() -> StringName:
	var reg: Dictionary = scan_maps()
	if reg.has(DEFAULT_AREA):
		return DEFAULT_AREA
	return FALLBACK_AREA


## Registers an in-memory map under an id (tests, tools): it behaves like a file of data/maps and counts as a fixture.
static func register_map(id: StringName, m: AreaMap) -> void:
	scan_maps()
	_registry[id] = {"path": "", "fixture": true, "map": m}


static func unregister_map(id: StringName) -> void:
	if _registry.has(id) and _registry[id].get("map", null) != null:
		_registry.erase(id)


static func load_map(id: StringName) -> AreaMap:
	var reg: Dictionary = scan_maps()
	if not reg.has(id):
		return null
	var entry: Dictionary = reg[id]
	if entry.get("map", null) != null:
		return (entry["map"] as AreaMap)
	return AreaMap.load_file(str(entry["path"]))


# ------------------------------------------------------------------ boot

func _ready() -> void:
	add_to_group("world_2d")
	GameManager.change_phase(GameManager.GamePhase.PLAYING)   # the 2D game never captures the mouse: the cursor stays visible
	holder = Node2D.new()
	holder.name = "AreaHolder"
	add_child(holder)
	if ResourceLoader.exists(FARM_GRID_PATH):
		var fs: Script = load(FARM_GRID_PATH) as Script
		if fs != null and fs.can_instantiate():
			farm = fs.new() as Node
			if farm != null:
				farm.name = "FarmGrid"
				add_child(farm)
	greenhouse_farm = FarmGrid.new()
	greenhouse_farm.name = "GreenhouseFarm"
	greenhouse_farm.map_path = "res://data/maps/greenhouse.map"
	add_child(greenhouse_farm)
	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.glow_changed.connect(_on_glow_changed)
	player = _make_player()
	add_child(player)
	weather_fx = WeatherFx.new()
	add_child(weather_fx)
	if ResourceLoader.exists(GAME_UI_PATH):
		var ui_scene: PackedScene = load(GAME_UI_PATH) as PackedScene
		if ui_scene != null:
			game_ui = ui_scene.instantiate()
			game_ui.name = "GameUI"
			add_child(game_ui)
	DungeonRun.attach(self)
	_build_vignette()
	_build_fade()
	art_prefetch = AreaArtPrefetch.new()
	art_prefetch.world = self
	add_child(art_prefetch)
	Svc.static_call("res://scripts/farm/steading/objects/farm_stage.gd", &"attach", [self])
	Svc.static_call("res://scripts/farm/farm_equipment.gd", &"attach", [self])
	Svc.static_call("res://scripts/traetoppen/life/daily_flags.gd", &"attach_world", [self])
	Svc.static_call("res://scripts/farm/steading/tutorial/tutorial_hints.gd", &"attach", [self])
	Svc.static_call("res://scripts/world2d/story/mother_director.gd", &"attach", [self])
	EventBus.area_change_requested.connect(_on_area_change_requested)
	EventBus.game_event.connect(_on_game_event)
	EventBus.player_defeated.connect(_on_player_defeated)
	EventBus.quest_completed.connect(_on_quest_completed)
	EventBus.home_upgraded.connect(_on_home_upgraded)
	EventBus.furniture_changed.connect(_on_furniture_changed)
	EventBus.player_spawned.emit(player)

	var start: StringName = default_area_id()
	var spawn: StringName = &"default"
	var saved: Dictionary = _take_pending_world()
	if not saved.is_empty() and has_area(StringName(str(saved.get("area", "")))):
		start = StringName(str(saved["area"]))
	if not _enter(start, spawn) and start != FALLBACK_AREA:
		_enter(FALLBACK_AREA, spawn)             # a registered default whose map file is bad must not leave the world without an area
	if not saved.is_empty():
		_apply_saved(saved)                      # puts the player back only when the area entered IS the saved one
	_welcome_toast(saved)
	ContractManifest.report()
	await warm_clips()
	_maybe_intro()
	ready_for_play = true


## The toast of a world start: the TITLE OF THE ZONE the player arrives in (ZONE_FARM -> "Trætoppen") and nothing else; it used to be
## GAME_TITLE + zone title, which is the same word twice in Danish. A Continue that lands in the area it was saved in shows nothing
## (the player knows where he is); a new game, and a Continue that had to fall back to another area, show the title. A map without
## a @title shows nothing. `saved` is the SaveManager.pending_world dictionary ({} = new game).
func _welcome_toast(saved: Dictionary) -> void:
	if area == null or area.map.title == "":
		return
	if not saved.is_empty():
		var saved_id := StringName(str(saved.get("area", "")))
		if saved_id == &"" or saved_id == area.map.id:
			return
	EventBus.notification_posted.emit(tr(area.map.title), "", "welcome")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		free_parked_areas()


## The world sets the clear colour of the area it shows (navy in the forest, plum in the home); RenderingServer keeps it for the whole
## process, so the title scene after a quit to menu would inherit it. Leaving the tree puts the PROJECT default back; coming back
## (remove_child / add_child of the world) sets the area's colour again.
func _enter_tree() -> void:
	if area != null and day_night != null:
		_apply_clear_color()


func _exit_tree() -> void:
	RenderingServer.set_default_clear_color(project_clear_color())


## The clear colour of project.godot (rendering/environment/defaults/default_clear_color) - what every scene without an area shows.
static func project_clear_color() -> Color:
	var v: Variant = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color", Color("a9d3e0"))
	return v as Color if v is Color else Color("a9d3e0")


## Parked iso areas live OUTSIDE the tree, referenced only by `_cache`, so nothing else frees them: when the world itself is deleted
## (quit to menu changes the scene) every parked area, with its nodes, colliders and light RIDs, would leak once per cycle.
## Frees every cached area that has no parent (the entered one is a child of AreaHolder and goes with the tree) and clears the
## cache. Returns how many were freed. Called on NOTIFICATION_PREDELETE; tests may call it too.
func free_parked_areas() -> int:
	var freed: int = 0
	for id in _cache.keys():
		var v: Variant = _cache[id]
		if is_instance_valid(v) and (v as Node).get_parent() == null:
			(v as Node).free()
			freed += 1
	_cache.clear()
	return freed


## SaveManager.pending_world (P15) is consumed once: the world applies it and clears it.
func _take_pending_world() -> Dictionary:
	var sm: Node = GameData.autoload("SaveManager")
	if sm == null:
		return {}
	var v: Variant = sm.get("pending_world")
	if not (v is Dictionary) or (v as Dictionary).is_empty():
		return {}
	var d: Dictionary = (v as Dictionary).duplicate(true)
	sm.set("pending_world", {})
	return d


func _make_player() -> Node2D:
	if ResourceLoader.exists(PLAYER_SCENE_PATH):
		var ps: PackedScene = load(PLAYER_SCENE_PATH) as PackedScene
		if ps != null:
			var p: Node = ps.instantiate()
			if p is Node2D:
				_give_farm(p)
				return p as Node2D
	var stub := PlayerStub2D.new()
	stub.name = "Player"
	_give_farm(stub)
	return stub


func _give_farm(p: Node) -> void:
	if farm != null and "farm" in p:
		p.set("farm", farm)

func farm_for_area(id: StringName) -> Node:
	return greenhouse_farm if id == &"greenhouse" else farm


## Opening hook (P14): on a NEW game the world calls IntroSequence once: `run(world)` (or `start` / `play`), static or on an instance,
## awaitable. Until scripts/world2d/intro_sequence.gd exists the flag stays set, so the intro plays as soon as it does.
func _maybe_intro() -> void:
	if not bool(GameManager.get_flag(GameManager.FLAG_INTRO_PENDING, false)):
		return
	var s: Script = intro_script
	if s == null:
		if not ResourceLoader.exists(intro_script_path):
			return
		s = load(intro_script_path) as Script
	if s == null:
		return
	var methods: Dictionary = {}
	for m in s.get_script_method_list():
		methods[str(m["name"])] = (int(m["flags"]) & METHOD_FLAG_STATIC) != 0
	var entry: String = ""
	for candidate in INTRO_ENTRY_POINTS:
		if methods.has(candidate):
			entry = candidate
			break
	if entry == "":
		return
	GameManager.set_flag(GameManager.FLAG_INTRO_PENDING, false)
	if bool(methods[entry]):
		s.call(entry, self)
	elif s.can_instantiate():
		var inst: Object = s.new()
		if inst is Node:
			add_child(inst as Node)
		if inst != null:
			inst.call(entry, self)


# ------------------------------------------------------------------ areas

## Builds the area of a registered map inside AreaHolder. `m` is the map when the caller already loaded (and validated) it.
func _create_area(id: StringName, m: AreaMap = null) -> IsoArea:
	if m == null:
		m = load_map(id)
	if m == null:
		return null
	var a := IsoArea.new()
	holder.add_child(a)                      # must be inside the tree before setup() (to_global needs it)
	a.setup(m)
	return a


## Is this area parked in the cache when the player leaves it? Iso areas without a builder are; ortho areas are rebuilt per
## visit, and a builder area (the home interior: its room changes with the tier) is NEVER parked.
static func is_parkable(a: IsoArea) -> bool:
	return a.projection == &"iso" and not a.map.is_builder()


func _enter(id: StringName, spawn: StringName) -> bool:
	if not has_area(id):
		last_travel_error = "no such area: %s" % id
		return false
	last_travel_error = ""
	# Validate BEFORE anything is torn down: a registered map whose file is empty / gone must leave the world in the area it is in
	# (to_dict() and the player's parent both need a current area). A parked area, or re-entering the current parkable one, needs no load.
	var m: AreaMap = null
	var reuse: bool = _cache.has(id) or (area != null and area.map.id == id and is_parkable(area))
	if not reuse:
		m = load_map(id)
		if m == null:
			last_travel_error = "cannot load map of %s (%s)" % [id, AreaMap.last_error]
			return false
	# park the player so it is never freed together with an old area
	if player.get_parent() != self:
		player.get_parent().remove_child(player)
		add_child(player)
	var prev_zone: StringName = _zone
	if area != null:
		holder.remove_child(area)
		if is_parkable(area):
			_cache[area.map.id] = area       # keep: crops, props, NPC state stay alive
		else:
			area.queue_free()
		area = null
	var next: IsoArea = null
	if _cache.has(id):
		next = _cache[id]
		holder.add_child(next)
	else:
		next = _create_area(id, m)
	if next == null:
		last_travel_error = "cannot load map of %s (%s)" % [id, AreaMap.last_error]
		return false
	area = next
	_rebuild_queued = false                  # the room that was just built read the CURRENT tier / furniture: nothing is left to rebuild
	_ensure_farm_view()
	player.call("enter_area", area, area.get_spawn(String(spawn)))
	_apply_ambient()
	area.on_enter()
	_apply_mode()
	_apply_zone(prev_zone)
	EventBus.area_changed.emit(id)
	area_ready.emit(id)
	return true


## The crop view (P06's FarmView, `setup(farm, area)`) lives in every area that has tillable cells, once the farm model exists.
func _ensure_farm_view() -> void:
	var model := farm_for_area(area.map.id)
	if model == null or area.farmable.is_empty() or area.get_node_or_null("FarmView") != null or not ResourceLoader.exists(FARM_VIEW_PATH):
		return
	var vs: Script = load(FARM_VIEW_PATH) as Script
	if vs == null or not vs.can_instantiate():
		return
	var fv: Node = vs.new() as Node
	if fv == null:
		return
	fv.name = "FarmView"
	area.add_child(fv)
	if fv.has_method("setup"):
		fv.call("setup", model, area)


## DayNight preset, clear colour, vignette, rain, glow factor of the current area.
func _apply_ambient() -> void:
	day_night.set_ambient(area.map.ambient)
	day_night.snap()
	_apply_clear_color()
	var strength: float = day_night.vignette_strength
	_vignette.visible = strength > 0.0
	_vignette_rect.modulate.a = clampf(strength / 0.78, 0.0, 1.0)
	weather_fx.set_area(day_night.weather_allowed and area.projection == &"iso", day_night.wind)
	area.set_night_factor(day_night.glow_factor)


## The clear colour of the current ambient preset (lua/config/ambient.lua `clear`).
func _apply_clear_color() -> void:
	var cfg: Dictionary = GameData.dict_of(GameData.cfg("ambient.clear", {}))
	var key: String = String(day_night.preset_id())
	var clear_hex: String = str(cfg.get(key, "a9d3e0"))
	RenderingServer.set_default_clear_color(Color.from_string(clear_hex, Color("a9d3e0")))


## GameUI mode and the clock: the calendar only runs in the iso areas; the forest has its own clock (lantern oil).
func _apply_mode() -> void:
	if game_ui != null and game_ui.has_method("set_mode"):
		game_ui.call("set_mode", &"action" if area.projection == &"ortho" else &"farm")
	var tm: Node = GameData.tm()
	if tm != null:
		tm.call("pause_time" if area.projection == &"ortho" else "resume_time")


func _zone_of_area() -> StringName:
	if area.map.zone != &"":
		return area.map.zone
	var table: Dictionary = GameData.dict_of(GameData.cfg("ambient.area_zone", {}))
	return StringName(str(table.get(String(area.map.id), String(area.map.id))))


## zone_entered is emitted ONLY here; zone_exited when the zone changes; the zone unlocks through GameManager.
func _apply_zone(prev_zone: StringName) -> void:
	var zone: StringName = _zone_of_area()
	_zone = zone
	GameManager.unlock_zone(zone)
	if prev_zone != &"" and prev_zone != zone:
		EventBus.zone_exited.emit(prev_zone)
	EventBus.zone_entered.emit(zone)


func current_zone() -> StringName:
	return _zone


func _on_area_change_requested(area_id: StringName, spawn_name: StringName) -> void:
	travel(area_id, spawn_name)


## Fade out, swap, warm the sprite clips behind the fade, fade in. Safe to await.
func travel(area_id: StringName, spawn: StringName) -> void:
	if GameManager.is_modal_open(&"event"): return
	if traveling or not has_area(area_id):
		if not has_area(area_id):
			last_travel_error = "no such area: %s" % area_id
			# a walk-in door to a place that is not built yet would refuse in silence: the player hears the gate is closed
			EventBus.whisper_requested.emit("WORLD_WARP_LOCKED")
		return
	traveling = true
	var began := Time.get_ticks_usec()
	last_travel_profile = {}
	art_prefetch.request(area_id)
	last_travel_profile.request_ms = (Time.get_ticks_usec()-began)/1000.0
	var tw: Tween = create_tween()
	tw.tween_property(_fade, "color:a", 1.0, FADE_OUT)
	await tw.finished
	await art_prefetch.finish()
	art_prefetch.request(area_id)
	await art_prefetch.finish()
	last_travel_profile.prefetch_and_fade_ms = (Time.get_ticks_usec()-began)/1000.0
	last_travel_profile.prepared_paths = art_prefetch.staged.keys()
	_enter(area_id, spawn)
	last_travel_profile.entered_ms = (Time.get_ticks_usec()-began)/1000.0
	await warm_clips()
	art_prefetch.release()
	last_travel_profile.warmed_ms = (Time.get_ticks_usec()-began)/1000.0
	_flush_rebuild()                         # a tier / furniture change that arrived since _enter: rebuilt behind the black screen
	var tw2: Tween = create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, FADE_IN)
	await tw2.finished
	traveling = false
	last_travel_profile.total_ms = (Time.get_ticks_usec()-began)/1000.0
	_flush_rebuild()                         # one that arrived during the fade-in
	if _pass_out_pending:
		_pass_out_pending = false
		await _sleep_sequence(true)


## The sprite warm-ups the next seconds need: [[visual, clips], ...] = the player's visual and the NPCs in view (pure: tests read it).
func warm_jobs() -> Array:
	var jobs: Array = []
	if player == null:
		return jobs
	var pv: Variant = player.get("visual") if "visual" in player else null
	if pv is Object and (pv as Object).has_method("warm_clips"):
		jobs.append([pv, PLAYER_WARM_CLIPS])
	for n in get_tree().get_nodes_in_group("npc"):
		if area == null or not area.objects.is_ancestor_of(n):
			continue
		var nv: Variant = n.get("visual") if "visual" in n else null
		if nv is Object and (nv as Object).has_method("warm_clips") and _in_view(n as Node2D):
			var flyer: bool = "flyer" in nv and bool(nv.get("flyer"))
			var walks: bool = ("wander_radius" in n and float(n.get("wander_radius")) > 0.0) or ("routine_id" in n and str(n.get("routine_id")) != "")
			var keeper := false
			if area.has_meta("room_spec") and "npc_id" in n:
				var building: String = str(area.get_meta("room_spec").get("building", ""))
				var row: Dictionary = GameData.lua().get_registry("buildings").get(building, {})
				keeper = str(row.get("keeper", "")) == str(n.get("npc_id"))
			jobs.append([nv, ["idle", "talk"] if keeper else (["idle", "talk", "hover"] if flyer else (["idle", "talk", "walk"] if walks else ["idle", "talk"]))])
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if area != null and area.objects.is_ancestor_of(enemy) and is_instance_valid(enemy.get("visual")):
			jobs.append([enemy.get("visual"),["idle","walk","run","hit","interact","sleep","fly","hover","spin","attack","jump","land"]])
	return jobs


## Warms the clip sheets the next seconds need (the player's and the NPCs in view) so the first step / the first word does not
## hitch. IsoChibiSprite2D.warm_clips() requests the sheets on worker threads and finalises one per frame, so this is meant to run
## behind the fade. The DUMMY renderer of headless runs has no GPU upload to hide, and creating textures from loader threads there
## raced in about 2 percent of the runs (engine message "texture_2d_initialize: Parameter t is null" + a leaked RID at exit, measured:
## 2 of 120 runs with the warm-up, 0 of 120 without), so headless runs skip it unless `warm_in_headless` is set.
func warm_clips() -> void:
	# Population waits for collider registration. Warm only after those real
	# citizens have appeared, so their first frame is also behind the travel fade.
	for director in get_tree().get_nodes_in_group("town_director"):
		if area != null and area.is_ancestor_of(director):
			while is_instance_valid(director) and director.is_inside_tree() and not director.ready_for_population:
				await get_tree().physics_frame
	if DisplayServer.get_name() == "headless" and not warm_in_headless:
		warm_skipped += 1
		return
	for j in warm_jobs():
		await (j[0] as Object).call("warm_clips", j[1])


func _in_view(n: Node2D) -> bool:
	if n == null or player == null:
		return false
	var zoom: float = 1.0
	if "camera" in player and player.get("camera") is Camera2D:
		zoom = maxf((player.get("camera") as Camera2D).zoom.x, 0.01)
	var half: Vector2 = get_viewport().get_visible_rect().size / zoom * 0.5 * 1.25
	return absf(n.global_position.x - player.global_position.x) <= half.x and absf(n.global_position.y - player.global_position.y) <= half.y


func _on_glow_changed(f: float) -> void:
	if area != null:
		area.set_night_factor(f)


# ------------------------------------------------------------------ rooms that change (builder areas)

func _on_home_upgraded(_old_tier: int, _new_tier: int) -> void:
	_queue_rebuild()


func _on_furniture_changed(reason: StringName) -> void:
	if reason in REBUILD_REASONS:
		_queue_rebuild()


func _queue_rebuild() -> void:
	if area == null or not area.map.is_builder() or _rebuild_queued:
		return
	_rebuild_queued = true
	_run_queued_rebuild.call_deferred()


## The deferred half of _queue_rebuild(): runs the queued rebuild unless something else already handled it (an _enter built a fresh
## room, which clears the flag) or a travel / the night is running: then the request STAYS queued and _flush_rebuild() runs it.
func _run_queued_rebuild() -> void:
	if _rebuild_queued and not traveling:
		_flush_rebuild()


## Rebuilds the current area in place (a builder room after a tier or furniture change); the player keeps his position.
## While a travel or the night runs (`traveling`) the rebuild is only QUEUED, never dropped: the day roll inside the sleep sequence is
## exactly when the builders finish (home_upgraded), and the room has to be the new one when the player wakes up.
func rebuild_current_area() -> void:
	if traveling:
		_rebuild_queued = true
		return
	_rebuild_queued = false
	_rebuild_area()


## Runs a queued rebuild now (the end of a travel, the black screen of the sleep sequence). A request for a room the player has left
## is gone already: _enter() clears the flag, because the room it builds reads the current tier and furniture.
func _flush_rebuild() -> void:
	if not _rebuild_queued:
		return
	_rebuild_queued = false
	_rebuild_area()


func _rebuild_area() -> void:
	# A tier notification may queue work in the same frame that quit/load
	# removes this world. Never rebuild a detached or dying scene.
	if area == null or not is_inside_tree() or is_queued_for_deletion():
		return
	var id: StringName = area.map.id
	var at: Vector2 = player.global_position
	# like _enter: load the map first, so a file that went bad leaves the current room standing instead of an area-less world
	var m: AreaMap = load_map(id)
	if m == null:
		last_travel_error = "cannot load map of %s (%s)" % [id, AreaMap.last_error]
		return
	_cache.erase(id)
	player.get_parent().remove_child(player)
	add_child(player)
	holder.remove_child(area)
	area.queue_free()
	area = null
	var next: IsoArea = _create_area(id, m)
	if next == null:
		return
	area = next
	_ensure_farm_view()
	player.call("enter_area", area, at)
	_apply_ambient()
	area.on_enter()
	area_ready.emit(id)


# ------------------------------------------------------------------ sleep / pass out / faint / celebrate

## The earliest hour the bed accepts: config time.sleep_from_hour (default 18:00), held later while a festival with bed_hold runs
## (SocialManager.bed_hold_hour, the window end); the night after midnight counts too.
func can_sleep_now() -> bool:
	var h: int = int(GameManager.hour)
	return h >= sleep_from_hour() or h < GameManager.day_start_hour()


static func sleep_from_hour() -> int:
	var from := int(GameManager.config_value("time.sleep_from_hour", 18))
	var social := Svc.node("SocialManager")
	if social != null and social.has_method("bed_hold_hour"):
		from = maxi(from, int(social.call("bed_hold_hour")))
	return from


## E on the bed: sleep clip, fade out, next day (the farm grows), fade in. Energy and hearts are restored. Before 18:00 the bed
## only whispers WHISPER_TOO_EARLY.
func sleep() -> void:
	if GameManager.is_modal_open(&"event"): return
	if sleeping or traveling:
		return
	if not can_sleep_now():
		EventBus.whisper_requested.emit("WHISPER_TOO_EARLY")
		return
	await _sleep_sequence(false)


## Pass-out at 24:00: the clock crossed midnight (GameManager emits game_event midnight_passed), the day already rolled.
func _on_game_event(event_name: StringName, _payload: Dictionary) -> void:
	if event_name != &"midnight_passed":
		return
	if sleeping or player == null or area == null or area.projection != &"iso":
		return
	if traveling:
		_pass_out_pending = true
		return
	_sleep_sequence(true)


func _sleep_sequence(passed_out: bool) -> void:
	sleeping = true
	traveling = true
	_pose_for_sleep()
	var tw: Tween = create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.7)
	await tw.finished
	# The day roll: builders finish (home_upgraded / furniture_changed), crops grow, the weather is rolled. `traveling` is set for the
	# whole night, so a room that has to change is only QUEUED here and rebuilt below, behind the black screen, before the fade-in.
	GameManager.sleep_until_morning()
	if passed_out:
		_enter(_wake_area(), StringName(str(GameData.cfg("dungeon.hub.wake_spawn", "from_home"))))
		_pose_for_sleep()
		EventBus.notification_posted.emit(tr("NOTIF_PASSED_OUT_TITLE"), tr("NOTIF_PASSED_OUT"), "sleep")
	_restore_player()
	# The day-end autosave of a pass-out ran at 02:00 where the player collapsed; the morning at home is what a Continue must resume
	# (sleep_until_morning emits no second day_ended). The bed's own day end is saved after its clock already reads the morning.
	if passed_out and SaveManager.autosave_enabled:
		SaveManager.autosave()
	await get_tree().create_timer(0.9).timeout
	if _rebuild_queued:
		_flush_rebuild()
		_pose_for_sleep()                    # enter_area() of the new room must not wake the player before the fade-in
	var tw2: Tween = create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.6)
	await tw2.finished
	player.call("end_talk")
	if "forced_clip" in player:
		player.set("forced_clip", &"")
	var pv: Variant = player.get("visual") if "visual" in player else null
	if pv is Object and (pv as Object).has_method("play_loop"):
		(pv as Object).call("play_loop", &"idle")
	traveling = false
	sleeping = false
	_flush_rebuild()                         # a change that arrived while the fade-in ran


## The sleeping pose: the player is frozen (begin_talk) and plays the sleep clip until the fade-in is over.
func _pose_for_sleep() -> void:
	player.call("begin_talk", player.global_position)
	if "forced_clip" in player:
		player.set("forced_clip", &"sleep")
	var pv: Variant = player.get("visual") if "visual" in player else null
	if pv is Object and (pv as Object).has_method("play_loop"):
		(pv as Object).call("play_loop", &"sleep")


## Energy and hearts back to full after sleeping or fainting (Player2D and the stub both have the fields).
func _restore_player() -> void:
	if player.has_method("restore_after_sleep"):
		player.call("restore_after_sleep")
		return
	if "stamina" in player and "max_stamina" in player:
		player.set("stamina", player.get("max_stamina"))
	if "half_hearts" in player and "max_half_hearts" in player:
		player.set("half_hearts", player.get("max_half_hearts"))
		EventBus.player_health_changed.emit(int(player.get("half_hearts")), int(player.get("max_half_hearts")))


func _wake_area() -> StringName:
	var id := StringName(str(GameData.cfg("dungeon.hub.wake_area", "farm")))
	return id if has_area(id) else default_area_id()


## Gentle defeat: the next morning at home, all items kept, a rounded-down gold fee.
func _on_player_defeated() -> void:
	if _faint_pending:
		return
	_faint_pending = true
	await get_tree().create_timer(1.3).timeout
	# travel() refuses while a fade / sleep sequence runs: wait it out so the rescue teleport is not silently skipped
	var guard := 0
	while (traveling or sleeping) and guard < 600:
		await get_tree().process_frame
		guard += 1
	traveling = true
	var fade_out := create_tween()
	fade_out.tween_property(_fade, "color:a", 1.0, FADE_OUT)
	await fade_out.finished
	var floors: Variant = Svc.static_call("res://scripts/dungeon/floors/dungeon_floors.gd", &"inst", [])
	if floors is Node and floors.has_method("end_run"):
		floors.call("end_run", &"defeated")
	GameManager.sleep_until_morning()
	var loss := floori(float(EconomyManager.gold) * clampf(float(GameData.cfg("dungeon.defeat.gold_loss_pct", 10)), 0.0, 100.0) / 100.0)
	EconomyManager.spend_gold(loss)
	_enter(_wake_area(), StringName(str(GameData.cfg("dungeon.hub.wake_spawn", "from_home"))))
	if player.has_method("revive"):
		player.call("revive", player.global_position)
	_restore_player()
	EventBus.whisper_requested.emit("WHISPER_FAINT")
	Svc.static_call("res://scripts/dungeon_run/dungeon_run.gd", &"after_defeat", [loss])
	if SaveManager.autosave_enabled:
		SaveManager.autosave()
	var fade_in := create_tween()
	fade_in.tween_property(_fade, "color:a", 0.0, FADE_IN)
	await fade_in.finished
	traveling = false
	_pass_out_pending = false
	_faint_pending = false


func _on_quest_completed(_quest_id: StringName) -> void:
	var pv: Variant = player.get("visual") if player != null and "visual" in player else null
	if pv is Object and (pv as Object).has_method("play_action") and ("state" in player and int(player.get("state")) == 0):
		(pv as Object).call("play_action", &"celebrate")


# ------------------------------------------------------------------ chrome

func _build_vignette() -> void:
	_vignette = CanvasLayer.new()
	_vignette.name = "Vignette"
	_vignette.layer = 5
	_vignette_rect = TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.04, 0.05, 0.10, 0.0))
	g.set_color(1, Color(0.04, 0.05, 0.10, 0.78))
	g.add_point(0.55, Color(0.04, 0.05, 0.10, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.52)
	gt.fill_to = Vector2(1.0, 1.0)
	gt.width = 256
	gt.height = 256
	_vignette_rect.texture = gt
	_vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.add_child(_vignette_rect)
	_vignette.visible = false
	add_child(_vignette)


func _build_fade() -> void:
	var cl := CanvasLayer.new()
	cl.name = "FadeLayer"
	cl.layer = 100
	_fade = ColorRect.new()
	_fade.color = Color(0.11, 0.13, 0.22, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_fade)
	add_child(cl)


# ------------------------------------------------------------------ area flags

## Per-area flag (JSON-safe values: bool, int, float, String).
func set_area_flag(area_id: StringName, key: String, value: Variant) -> void:
	var d: Dictionary = area_flags.get(String(area_id), {})
	if value == null:
		d.erase(key)
	else:
		d[key] = value
	area_flags[String(area_id)] = d


func get_area_flag(area_id: StringName, key: String, default_value: Variant = null) -> Variant:
	return (area_flags.get(String(area_id), {}) as Dictionary).get(key, default_value)


# ------------------------------------------------------------------ save / load

## The world part of a save (SaveManager hands it back through pending_world): area id, player position, crops, hotbar, placed
## items and per-area flags. Everything is JSON-safe (vectors as arrays).
func to_dict() -> Dictionary:
	var d: Dictionary = {
		"v": 1,
		"area": String(area.map.id),
		"player_pos": [player.global_position.x, player.global_position.y],
		"placed": placed_items.duplicate(true),
		"area_flags": area_flags.duplicate(true),
	}
	if not placed_orphans.is_empty():
		d["placed_orphans"] = placed_orphans.duplicate(true)
	if farm != null and farm.has_method("to_dict"):
		d["farm"] = farm.call("to_dict")
	if greenhouse_farm != null:
		d["greenhouse_farm"] = greenhouse_farm.to_dict()
	var hb: Variant = player.get("hotbar") if "hotbar" in player else null
	if hb is Object and (hb as Object).has_method("to_dict"):
		d["hotbar"] = (hb as Object).call("to_dict")
	return d


## Applies a world dict synchronously (no fade): the saved area, position, crops, hotbar, placed items and flags.
func from_dict(d: Dictionary) -> void:
	var id := StringName(str(d.get("area", "")))
	if id != &"" and has_area(id) and (area == null or area.map.id != id):
		_enter(id, &"default")
	_apply_saved(d)


func _apply_saved(d: Dictionary) -> void:
	var saved_placed: Array = d.get("placed", []) if d.get("placed", []) is Array else []
	var saved_orphans: Array = d.get("placed_orphans", []) if d.get("placed_orphans", []) is Array else []
	var repaired: Dictionary = FarmEquipment.repair_placed(saved_placed, saved_orphans)
	placed_items = repaired["placed"]
	placed_orphans = repaired["orphans"]
	area_flags = (d.get("area_flags", {}) as Dictionary).duplicate(true) if d.get("area_flags", {}) is Dictionary else {}
	if farm != null and farm.has_method("from_dict") and d.has("farm"):
		farm.call("from_dict", d["farm"])
	if greenhouse_farm != null:
		greenhouse_farm.from_dict(d.get("greenhouse_farm", {"plots": {}}))
	var hb: Variant = player.get("hotbar") if "hotbar" in player else null
	if hb is Object and (hb as Object).has_method("from_dict") and d.has("hotbar"):
		(hb as Object).call("from_dict", d["hotbar"])
	# The coordinates belong to the area the save was made in. When that map is gone (renamed, removed, a save from another build)
	# the world entered the default area instead: keep the spawn point there, a position of another map is void in this one.
	var saved_id := StringName(str(d.get("area", "")))
	var same_area: bool = saved_id == &"" or (area != null and area.map.id == saved_id)
	if same_area and area != null and d.has("player_pos"):
		# a save file is untrusted: anything but two finite numbers is a damaged position and starts at the spawn
		var saved_pos: Variant = _saved_position(d["player_pos"])
		player.global_position = _inside_area(saved_pos as Vector2) if saved_pos is Vector2 else area.get_spawn("default")
		if "camera" in player and player.get("camera") is Camera2D:
			(player.get("camera") as Camera2D).reset_smoothing()
	state_applied.emit()


## `[x, y]` of a saved dictionary as a Vector2; null for anything else (not an Array, too short, an element that is no number -
## null, bool, string, Array, Dictionary - or is not finite). JSON numbers arrive as float, a hand-built dictionary may hold ints.
static func _saved_position(v: Variant) -> Variant:
	if not (v is Array) or (v as Array).size() < 2:
		return null
	var xy: Array = v
	for i in 2:
		var t: int = typeof(xy[i])
		if t != TYPE_FLOAT and t != TYPE_INT:
			return null
		if t == TYPE_FLOAT and not is_finite(xy[i] as float):
			return null
	return Vector2(float(xy[0]), float(xy[1]))


## A saved position of THIS area made safe: pulled into the camera rect, and sent to the default spawn when it still is not on the
## platform (a void cell: the map shrank since the save, or the save is damaged; a wall cell). Water and bog cells stay valid
## (fairies hover over ponds), and so do the void cells of a platform growth row that F6 has not turned into deck yet.
## A grid-less builder area keeps the position inside its `bounds` that passes `area.walkable_test` (when the builder set one).
func _inside_area(p: Vector2) -> Vector2:
	var r: Rect2 = area.camera_rect().grow(-1.0)
	var has_rect: bool = r.size.x > 0.0 and r.size.y > 0.0
	if has_rect:
		p = Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	if not area.map.has_grid():
		# a builder area (the home interior) has no ground rows - every cell would read as void: its bounds and its own walkable test decide
		if not has_rect or (area.walkable_test.is_valid() and not bool(area.walkable_test.call(p))):
			return area.get_spawn("default")
		return p
	var cell: Vector2i = area.global_to_cell(p)
	var ch: String = area.map.ground_at(cell)
	if ch == "W" or (ch == "#" and not _is_growth_cell(cell)):
		return area.get_spawn("default")
	return p


func _is_growth_cell(cell: Vector2i) -> bool:
	for stage in range(1, area.max_growth_stage() + 1):
		if cell in area.growth_cells(stage):
			return true
	return false
