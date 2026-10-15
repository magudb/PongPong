class_name IsoArea
extends Node2D
## One playable area (farm, Hyggebyen, Moerkeskoven, the home interior ...). Built at runtime from an AreaMap (ASCII), through ArtCatalog
## (real art or the placeholder fallback), AreaTileSet and the Lua tables lua/config/props.lua + marker_handlers.lua.
##
## Node tree (created in setup()):
##   IsoArea
##   |- Backdrop    Node2D z=-20    Parallax2D "Sky" + Parallax2D "Far" (ArtCatalog.backdrop(theme)): the platform floats in a visible sky
##   |- Ground      TileMapLayer    z=-10, texture_filter 2 (linear, atlases imported WITHOUT mipmaps): terrain; blockers carry physics
##   |- Water0..3   TileMapLayer    iso water: four layers with identical cells, ONE visible (swap every 0.5 s); physics on Water0 only
##   |- GroundFx    Node2D          z=-9, flat things on the floor: target marker, dust, decals
##   |- Skirts      Node2D          z=-9, NOT y-sorted: one platform skirt sprite per platform-edge cell (R.10)
##   |- Objects     Node2D          y_sort_enabled, texture_filter 4: props, strips, NPCs, enemies, crops, loot, the PLAYER
##   |    `- Walls  TileMapLayer    (ortho only) y-sorted wall tiles, solid
##   |- Colliders   Node2D          StaticBody2D of the solid props (layer world)
##   |- Triggers    Node2D          Warp2D / whisper areas ...
##   `- Bounds      StaticBody2D    hard rectangle just outside the playable rect (stops fliers)
##
## MARKERS (plan 3.7): `@marker <char> <type> k=v ...` + the char in the @objects rows. Built in: spawn, warp, sign, bed, quest_spot,
## light and the `growth` marker; every other type is resolved LAZILY through the registry (marker_registry(): the built-in table of
## LAZY_HANDLERS merged with lua/config/marker_handlers.lua) to a script path. A handler script is used only when it exists AND
## offers one of these entry points (first match wins):
##   static func create_marker(params: Dictionary, pos: Vector2, cell: Vector2i, area: IsoArea) -> Node
##   static func create(params: Dictionary, pos: Vector2) -> Node          (the world spike's WhisperZone)
##   static func create(params: Dictionary) -> Node                        (Npc2D, Enemy2D, ResourceNode2D: the framework sets the position)
##   func setup_marker(params: Dictionary, pos: Vector2, cell: Vector2i, area: IsoArea) -> void    (script.new() is the node)
## A type nobody handles, a script that does not exist yet and a script without an entry point are skipped SILENTLY and counted in
## skipped_markers (type -> count), so packages of later waves land independently. Every marker is also recorded in `markers`
## (find_markers(type)), so data markers (animal_yard, building_slot, field_expansion) can be read by their consumers.
## `when=` (quest:<id> | done:<id> | flag:<name> | night) is evaluated on enter and on quest / clock / flag changes.
## Built-in marker parameters: warp `to= spawn= label= [req_day=N] [r=cells] [prop=<art id>]`; sign `text=<key> [prop=]`; bed (no parameters);
## quest_spot `quest= objective= prompt=<key> [needs=item:n,item:n] [consume=1] [prop=]`; light `kind=lantern|glow [r=px color=hex h=px]`;
## growth `stage=1..3 cells=x,y;x0..x1,y0..y1` (plus every char of that marker in the @objects rows): void cells that become deck while
## set_growth_stage(rows) >= stage. `=` ground cells are bridge planks (bridge_x / bridge_z props, nothing under them).
##
## SPAWNS: every area has the spawn `default` (an `@` object char or `@marker <char> spawn name=default`). A map without one gets a
## fallback on the walkable cell nearest to the middle of the grid (a grid-less builder area: the middle of `bounds` / the play rect)
## and a `map.errors` entry, so the player never lands at global (0, 0), a void cell above the platform.
## BUILDER AREAS (`@builder <script>`, no grid): builder.build(area, header) fills the area and may set `area.bounds` (camera limits),
## `area.spawns["default"]`, `area.zoom_range` / `area.zoom_default` and `area.walkable_test` (Callable(global_pos: Vector2) -> bool):
## the saved position of a Continue is kept when it passes that test (and lies inside the bounds), else the player starts at the spawn.

signal built
signal growth_changed(rows: int)

const Z_GROUND := Iso.Z_GROUND
const Z_GROUND_FX := Iso.Z_GROUND_FX
const Z_SKIRTS := Iso.Z_SKIRTS
const STRIP_W := 32
const WATER_PERIOD := 0.5
const FLAG_POLL_PERIOD := 0.25

## Marker types the area builds itself.
const BUILTIN_MARKERS: Array[String] = ["spawn", "warp", "sign", "bed", "quest_spot", "light", "growth"]
## Types whose handler may use the world spike's `create(params[, pos])` entry points (Npc2D, Enemy2D, ResourceNode2D, WhisperZone).
## Every other type needs the explicit create_marker / setup_marker entry points, so a class that merely has an unrelated
## `create` (Animal2D.create(species)) is never mistaken for a marker handler.
const LEGACY_CREATE_TYPES: Array[String] = ["npc", "enemy", "node", "whisper"]

## Marker type -> handler script, resolved lazily (the script may not exist yet). lua/config/marker_handlers.lua is merged over it.
const LAZY_HANDLERS := {
	"npc": "res://scripts/world2d/npc_2d.gd",
	"enemy": "res://scripts/world2d/enemy_2d.gd",
	"node": "res://scripts/world2d/resource_node_2d.gd",
	"whisper": "res://scripts/world2d/whisper_zone.gd",
	"animal_yard": "res://scripts/farm/animal_2d.gd",
	"building_slot": "res://scripts/farm/placement_service.gd",
	"field_expansion": "res://scripts/world2d/farm_view.gd",
}

const SKIRT_SW := &"platform_sw"
const SKIRT_SE := &"platform_se"
const SKIRT_CORNER := &"platform_corner"
## Ground chars that are never platform (no skirt under them): bridge planks and void. Water IS platform: a pond on the rim of the
## platform gets its bark skirt like any deck cell, otherwise the cliff has a gap and the water floats like a sheet over the sky.
const NO_SKIRT_CHARS := "=#"
## Upper bound of the cells one `cells=` text of a growth marker may name when no map size is known (a mistyped range must not freeze the build).
const MAX_PARSED_CELLS := 16384

var map: AreaMap
var projection: StringName = &"iso"
var ground: TileMapLayer
var water_layers: Array[TileMapLayer] = []
var walls: TileMapLayer
var backdrop: Node2D
var ground_fx: Node2D
var skirts: Node2D
var objects: Node2D
var colliders: Node2D
var triggers: Node2D
var bounds_body: StaticBody2D
var spawns: Dictionary = {}                 # name -> global position
var farmable: Dictionary = {}               # Vector2i -> true
var markers: Array[Dictionary] = []         # every marker occurrence: {type, params, cell, pos, char, node, nodes}
var skipped_markers: Dictionary = {}        # marker type -> count of occurrences nobody handled
var unknown_chars: Dictionary = {}          # object / ground char -> count (declared nowhere)
var prop_nodes: Array[Dictionary] = []      # {id, cell, nodes: Array[Node2D], body: StaticBody2D}
var skirt_nodes: Dictionary = {}            # Vector2i -> Sprite2D
var marker_handlers: Dictionary = {}        # type -> Callable(params, pos, cell, area) -> Node: per-area override (wins over the registry)
var play_rect: Rect2 = Rect2()              # tight rect around walkable cells (global px)
## Camera limits of a builder area (Rect2, global px); an empty rect = use the playable rect. Player2D's Camera2D follows it.
var bounds: Rect2 = Rect2()
## Camera zoom range (x = min, y = max) and default of this area in the 1280 x 720 base: from the @zoom headers, builders may override.
var zoom_range: Vector2 = Vector2(Iso.ZOOM_MIN, Iso.ZOOM_MAX)
var zoom_default: float = Iso.DEFAULT_ZOOM
## Builders (grid-less areas): can the player stand at this GLOBAL position? Used for the saved position of a Continue. Optional.
var walkable_test: Callable = Callable()
var growth_stage: int = 0
var build_ms: int = 0
var builder_error: String = ""
var night_factor: float = 0.0

var _terrain_of: Dictionary = {}            # Vector2i -> terrain id of the ground tile
var _when_nodes: Array[Dictionary] = []     # {nodes: Array[Node], when: String, active: bool}
var _glows: Array[Dictionary] = []          # {node: CanvasItem, base: float}
var _lights: Array[Dictionary] = []         # {node: PointLight2D, base: float}
var _growth_cells: Dictionary = {}          # stage -> Array[Vector2i]
var _orig_ground: PackedStringArray = PackedStringArray()
var _water_frame: int = 0
var _water_t: float = 0.0
var _poll_t: float = 0.0
var _has_flag_when: bool = false
var _has_water: bool = false                # a `~` cell was painted: the four swap layers and the 0.5 s tick are needed
var _hooked: bool = false

static var _handler_cache: Dictionary = {}  # script path -> {"mode": String, "script": Script}


# ------------------------------------------------------------------ marker registry (static)

## type -> {"script": path ("" for built-in types), "builtin": bool}: the built-in table with lua/config/marker_handlers.lua merged
## OVER it (a Lua entry replaces the script of a lazy type, adds new types, and may replace a built-in one when its script exists).
static func marker_registry() -> Dictionary:
	var reg: Dictionary = {}
	for t in BUILTIN_MARKERS:
		reg[t] = {"script": "", "builtin": true}
	for t in LAZY_HANDLERS:
		reg[t] = {"script": str(LAZY_HANDLERS[t]), "builtin": false}
	var lua_table: Dictionary = GameData.marker_handlers()
	for t in lua_table:
		var v: Variant = lua_table[t]
		var path: String = ""
		if v is String:
			path = v
		elif v is Dictionary:
			path = str((v as Dictionary).get("script", ""))
		if path == "":
			continue
		var key: String = str(t)
		reg[key] = {"script": path, "builtin": bool((reg.get(key, {}) as Dictionary).get("builtin", false))}
	return reg


## How a marker type is handled right now: {"kind": "builtin" | "script" | "none", "script": Script or null, "mode": entry point name}.
static func resolve_handler(type: String) -> Dictionary:
	var reg: Dictionary = marker_registry()
	var entry: Dictionary = reg.get(type, {}) as Dictionary
	if entry.is_empty():
		return {"kind": "none", "script": null, "mode": ""}
	var path: String = str(entry.get("script", ""))
	if path != "":
		var api: Dictionary = _handler_api(path, type in LEGACY_CREATE_TYPES)
		if api["mode"] != "":
			return {"kind": "script", "script": api["script"], "mode": api["mode"]}
	if bool(entry.get("builtin", false)):
		return {"kind": "builtin", "script": null, "mode": ""}
	return {"kind": "none", "script": null, "mode": ""}


static func _handler_api(path: String, legacy: bool) -> Dictionary:
	var ckey: String = "%s|%s" % [path, legacy]
	if _handler_cache.has(ckey):
		return _handler_cache[ckey]
	var res: Dictionary = {"mode": "", "script": null}
	if ResourceLoader.exists(path):
		var s: Script = load(path) as Script
		if s != null:
			var arity: Dictionary = {}
			for m in s.get_script_method_list():
				arity[str(m["name"])] = (m["args"] as Array).size()
			var mode: String = ""
			if arity.get("create_marker", -1) == 4:
				mode = "create_marker"
			elif legacy and arity.get("create", -1) == 2:
				mode = "create2"
			elif legacy and arity.get("create", -1) == 1:
				mode = "create1"
			elif arity.get("setup_marker", -1) == 4 and s.can_instantiate():
				mode = "setup_marker"
			res = {"mode": mode, "script": s}
	_handler_cache[ckey] = res
	return res


## Forgets the cached entry points (tests that add handler scripts, hot reload).
static func clear_handler_cache() -> void:
	_handler_cache.clear()


# ------------------------------------------------------------------ setup

func setup(p_map: AreaMap) -> void:
	var t0: int = Time.get_ticks_msec()
	map = p_map
	name = String(map.id).capitalize() if String(map.id) != "" else "Area"
	projection = &"ortho" if map.projection == &"ortho" else &"iso"
	zoom_range = map.zoom_range()
	zoom_default = map.zoom_default()
	_orig_ground = map.ground.duplicate()
	_make_skeleton()
	if map.is_builder():
		_run_builder()
	else:
		_build_standard()
	_ensure_default_spawn()
	build_ms = Time.get_ticks_msec() - t0
	set_process(_has_water or _has_flag_when)
	built.emit()


func _make_skeleton() -> void:
	var ts: TileSet = AreaTileSet.tile_set(projection)
	backdrop = Node2D.new()
	backdrop.name = "Backdrop"
	backdrop.z_index = Iso.Z_BACKDROP
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(backdrop)
	ground = TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = ts
	ground.z_index = Z_GROUND
	ground.y_sort_enabled = true
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(ground)
	if projection == &"iso":
		for i in 4:
			var wl := TileMapLayer.new()
			wl.name = "Water%d" % i
			wl.tile_set = ts
			wl.z_index = Z_GROUND
			wl.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			wl.visible = i == 0
			add_child(wl)
			water_layers.append(wl)
	ground_fx = Node2D.new()
	ground_fx.name = "GroundFx"
	ground_fx.z_index = Z_GROUND_FX
	add_child(ground_fx)
	skirts = Node2D.new()
	skirts.name = "Skirts"
	skirts.z_index = Z_SKIRTS
	skirts.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(skirts)
	objects = Node2D.new()
	objects.name = "Objects"
	objects.y_sort_enabled = true
	objects.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(objects)
	if projection == &"ortho":
		walls = TileMapLayer.new()
		walls.name = "Walls"
		walls.tile_set = ts
		walls.y_sort_enabled = true
		walls.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		objects.add_child(walls)
	colliders = Node2D.new()
	colliders.name = "Colliders"
	add_child(colliders)
	triggers = Node2D.new()
	triggers.name = "Triggers"
	add_child(triggers)


func _build_standard() -> void:
	_collect_growth_cells()
	_paint_ground()
	_compute_play_rect()
	if projection == &"iso":
		_rebuild_skirts()
	_build_bounds()
	_build_backdrop()
	_place_bridges()
	_build_objects()


func _run_builder() -> void:
	## Header-only area: builder.build(area, header) constructs it (F6's HomeRoom). A missing script is silent (builder_error).
	var path: String = map.builder
	if not ResourceLoader.exists(path):
		builder_error = "builder script %s does not exist" % path
		_build_bounds()
		return
	var s: Script = load(path) as Script
	if s == null:
		builder_error = "builder %s is not a script" % path
		return
	var header: Dictionary = header_dict()
	var script_methods: Dictionary = {}
	for m in s.get_script_method_list():
		script_methods[str(m["name"])] = true
	if not script_methods.has("build"):
		builder_error = "builder %s has no build(area, header)" % path
		return
	var inst: Variant = s
	if not _is_static_method(s, "build"):
		inst = s.new()
	inst.call("build", self, header)
	if not has_bounds() and play_rect.size == Vector2.ZERO:
		_compute_play_rect()
	_build_bounds()


static func _is_static_method(s: Script, method: String) -> bool:
	for m in s.get_script_method_list():
		if str(m["name"]) == method:
			return (int(m["flags"]) & METHOD_FLAG_STATIC) != 0
	return false


## The header values a builder receives.
func header_dict() -> Dictionary:
	return {
		"id": map.id, "title": map.title, "projection": map.projection, "ambient": map.ambient, "theme": map.theme,
		"zone": map.zone, "depth": map.depth, "flight": map.flight_allowed, "music": map.music, "zoom": map.zoom_default(),
		"zoom_min": zoom_range.x, "zoom_max": zoom_range.y, "builder": map.builder, "extra": map.extra.duplicate(), "map": map,
	}


# ------------------------------------------------------------------ coordinate helpers (global space)

func cell_to_global(c: Vector2i) -> Vector2:
	return ground.to_global(ground.map_to_local(c))


func global_to_cell(p: Vector2) -> Vector2i:
	return ground.local_to_map(ground.to_local(p))


func facing_step(dir8: int) -> Vector2i:
	return Iso.DIR8_TO_CELL_STEP[dir8] if projection == &"iso" else Iso.DIR8_TO_ORTHO_STEP[dir8]


## Terrain id of the ground tile of a cell (&"" for void, bridge planks and cells without a tile).
func cell_kind(c: Vector2i) -> StringName:
	return _terrain_of.get(c, &"")


func is_walkable(c: Vector2i) -> bool:
	var ch: String = map.ground_at(c)
	if ch == "#" or ch == "~" or ch == "W":
		return false
	return true


func is_farmable(c: Vector2i) -> bool:
	return farmable.has(c)


## Swaps the terrain of one cell (FarmGrid: soil_tilled / soil_watered). reset_terrain() restores what the map says.
func set_terrain(c: Vector2i, terrain_id: StringName) -> void:
	var sid: int = AreaTileSet.source_for(projection, terrain_id)
	ground.set_cell(c, sid, AreaTileSet.atlas_coords_for(terrain_id, c))
	_terrain_of[c] = terrain_id


func reset_terrain(c: Vector2i) -> void:
	var id: StringName = terrain_for_char(map.ground_at(c), c)
	if id == &"":
		return
	set_terrain(c, id)


func get_spawn(spawn_name: String) -> Vector2:
	if spawns.has(spawn_name):
		return spawns[spawn_name]
	if spawns.has("default"):
		return spawns["default"]
	return camera_rect().get_center()      # setup() always defines `default` (_ensure_default_spawn); only an area not set up gets here


## The spawn `default` is mandatory. A map without one (no `@` char, no `spawn name=default` marker) gets the walkable, empty cell nearest
## to the middle of the grid; a builder area without a grid and without a spawn gets the middle of its bounds / play rect. Either way
## `map.errors` says what is missing, once, so the map author sees it (the area still works).
func _ensure_default_spawn() -> void:
	if spawns.has("default"):
		return
	var pos: Vector2 = Vector2.ZERO
	var found: bool = false
	if map.has_grid():
		var mid := Vector2(float(map.width - 1) * 0.5, float(map.height - 1) * 0.5)
		var best: float = INF
		var best_cell := Vector2i.ZERO
		for y in map.height:
			for x in map.width:
				var c := Vector2i(x, y)
				if not _is_spawn_candidate(c):
					continue
				var d: float = Vector2(c).distance_squared_to(mid)
				if d < best:
					best = d
					best_cell = c
					found = true
		if found:
			pos = cell_to_global(best_cell)
	if not found:
		var r: Rect2 = camera_rect()
		pos = r.get_center() if r.size != Vector2.ZERO else global_position
	spawns["default"] = pos
	var msg: String = "no default spawn (an '@' object char or `@marker <char> spawn name=default`): the player starts on the walkable cell nearest to the middle"
	if not map.has_grid():
		msg = "builder area sets no default spawn (area.spawns[\"default\"]): the player starts in the middle of the bounds"
	if not map.errors.has(msg):
		map.errors.append(msg)


## A cell the fallback spawn may use: ground the player can walk on and nothing placed on it (no prop, marker or other object char).
func _is_spawn_candidate(c: Vector2i) -> bool:
	var ch: String = map.ground_at(c)
	if ch == "#" or ch == "~" or ch == "W" or ch == "=":
		return false
	var oc: String = map.object_at(c)
	return oc == "." or oc == " "


func has_bounds() -> bool:
	return bounds.size.x > 0.0 and bounds.size.y > 0.0


## Camera limits: the builder's `bounds` when set, else the playable rect (iso: plus half a tile so the platform skirts show,
## ortho: exactly the map, walls fill it).
func camera_rect() -> Rect2:
	if has_bounds():
		return bounds
	if projection == &"ortho":
		return play_rect
	return play_rect.grow(Iso.TILE_W * 0.5)


## Camera limits that work for a view larger than the rect: a rect smaller than the view is centred (otherwise Camera2D limits
## smaller than the view stick to the top-left). `view` = viewport size / zoom, in global px.
static func camera_limits_for(rect: Rect2, view: Vector2) -> Rect2:
	var out: Rect2 = rect
	if out.size.x < view.x:
		out.position.x = rect.get_center().x - view.x * 0.5
		out.size.x = view.x
	if out.size.y < view.y:
		out.position.y = rect.get_center().y - view.y * 0.5
		out.size.y = view.y
	return out


# ------------------------------------------------------------------ ground

## Terrain id of a ground char for this area's projection and theme (&"" = no tile: void, bridge planks, unknown).
func terrain_for_char(ch: String, _c: Vector2i = Vector2i.ZERO) -> StringName:
	if projection == &"ortho":
		match ch:
			"m", "n", "o", ".":
				return &"forest_floor_o"
			"g":
				return &"forest_floor_glow_o"
			"p":
				return &"moss_path_o"
			"~":
				return &"bog_o"
			"c":
				return &"cave_floor_o"
			"x":
				return &"crystal_floor_o"
			"W":
				return &"wall_void_o"
		return &""
	var theme: StringName = map.theme
	var town: bool = theme == &"hyggebyen"
	var dark: bool = theme == &"forest" or theme == &"cave"
	match ch:
		".", "f":
			return &"forest_floor" if dark else (&"grass_hyggebyen" if town else &"grass")
		",", ";":
			return &"forest_floor_glow" if dark else (&"grass_hyggebyen_flowers" if town else &"grass_flowers")
		"p":
			return &"forest_floor_glow" if dark else &"path_dirt"
		"c":
			return &"cobble_hyggebyen"
		"d":
			return &"deck_hyggebyen" if town else &"deck_farm"
		"~":
			return &"water_0"
		"m", "n", "o", "g", "x", "W":
			return &"forest_floor_glow" if ch == "g" or ch == "x" else &"forest_floor"
	return &""


func _paint_ground() -> void:
	for y in map.height:
		for x in map.width:
			_paint_cell(Vector2i(x, y))
	if projection == &"iso":
		_place_iso_walls()


func _paint_cell(c: Vector2i) -> void:
	var ch: String = map.ground_at(c)
	if ch == "#":
		_set_void_cell(c)
		return
	if ch == "=":
		_clear_cell(c)
		return
	var id: StringName = terrain_for_char(ch, c)
	if id == &"":
		unknown_chars[ch] = int(unknown_chars.get(ch, 0)) + 1
		return
	if ch == "f":
		farmable[c] = true
	if ch == "W" and projection == &"ortho":
		# a flat dark floor under the wall so the sort order never shows a hole
		ground.set_cell(c, AreaTileSet.source_for(projection, &"wall_void_o"), AreaTileSet.atlas_coords_for(&"wall_void_o", c))
		_terrain_of[c] = &"wall_void_o"
		walls.set_cell(c, AreaTileSet.wall_source_for(_wall_prop_for(c)), Vector2i(0, 0))
		return
	if ch == "~" and projection == &"iso":
		for i in water_layers.size():
			var wid: StringName = AreaTileSet.WATER_FRAMES[i]
			water_layers[i].set_cell(c, AreaTileSet.source_for(projection, wid), AreaTileSet.atlas_coords_for(wid, c))
		_terrain_of[c] = &"water_0"
		_has_water = true
		return
	set_terrain(c, id)


## Plank cells ('=' ground chars) carry a bridge piece each (rails and posts are part of the art): bridge_x along the map columns
## (screen lower-right), bridge_z along the rows (lower-left). The ground under the planks stays empty (the sky shows through).
func _place_bridges() -> void:
	if projection != &"iso":
		return
	for y in map.height:
		for x in map.width:
			var c := Vector2i(x, y)
			if map.ground_at(c) != "=":
				continue
			var along_x: bool = map.ground_at(Vector2i(x - 1, y)) == "=" or map.ground_at(Vector2i(x + 1, y)) == "="
			if not along_x and map.ground_at(Vector2i(x, y - 1)) != "=" and map.ground_at(Vector2i(x, y + 1)) != "=":
				along_x = not map.is_void(Vector2i(x - 1, y)) or not map.is_void(Vector2i(x + 1, y))
			place_prop("bridge_x" if along_x else "bridge_z", c)


## Iso fallback of the forest maps (`@projection iso`): a wall char becomes a solid pine on a full-cell blocker.
func _place_iso_walls() -> void:
	for y in map.height:
		for x in map.width:
			var c := Vector2i(x, y)
			if map.ground_at(c) != "W":
				continue
			place_prop("tree_pine_forest", c)
			var body := StaticBody2D.new()
			body.name = "Wall_%d_%d" % [x, y]
			body.collision_layer = Iso.LAYER_WORLD
			body.collision_mask = 0
			body.position = Iso.iso_center(c)
			var cs := CollisionShape2D.new()
			var sh := ConvexPolygonShape2D.new()
			sh.points = AreaTileSet.diamond_points()
			cs.shape = sh
			body.add_child(cs)
			colliders.add_child(body)


func _wall_prop_for(c: Vector2i) -> StringName:
	var cave: bool = map.theme == &"cave" or map.ambient == &"cave"
	var pool: Array = [&"cave_wall_a", &"cave_wall_b"] if cave else [&"forest_wall_a", &"forest_wall_b", &"forest_wall_c"]
	return pool[int(PlaceholderArt._hash(float(c.x), float(c.y)) * float(pool.size())) % pool.size()]


## Void cell: an invisible ground_block blocker when a walkable cell is next to it (the void rim), else nothing.
func _set_void_cell(c: Vector2i) -> void:
	_clear_cell(c)
	if _near_walkable(c):
		ground.set_cell(c, AreaTileSet.SRC_BLOCKER, Vector2i(0, 0))


func _clear_cell(c: Vector2i) -> void:
	ground.erase_cell(c)
	if walls != null:
		walls.erase_cell(c)
	for wl in water_layers:
		wl.erase_cell(c)
	_terrain_of.erase(c)
	farmable.erase(c)


func _near_walkable(c: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dy != 0) and not map.is_void(Vector2i(c.x + dx, c.y + dy)):
				return true
	return false


func _compute_play_rect() -> void:
	var r := Rect2()
	var first: bool = true
	var half := Vector2(Iso.TILE_W * 0.5, Iso.TILE_H * 0.5) if projection == &"iso" else Vector2(Iso.ORTHO_W * 0.5, Iso.ORTHO_H * 0.5)
	for y in map.height:
		for x in map.width:
			if map.is_void(Vector2i(x, y)):
				continue
			var p: Vector2 = cell_to_global(Vector2i(x, y))
			var cr := Rect2(p - half, half * 2.0)
			if first:
				r = cr
				first = false
			else:
				r = r.merge(cr)
	play_rect = r


func _build_bounds() -> void:
	if bounds_body != null:
		bounds_body.queue_free()
		bounds_body = null
	var base: Rect2 = bounds if has_bounds() else play_rect
	if base.size == Vector2.ZERO:
		return
	var body := StaticBody2D.new()
	body.name = "Bounds"
	body.collision_layer = Iso.LAYER_WORLD
	body.collision_mask = 0
	var outer: Rect2 = base.grow(maxf(Iso.TILE_W, Iso.ORTHO_W) * 1.5)
	var t: float = 200.0
	var rects: Array[Rect2] = [
		Rect2(outer.position.x - t, outer.position.y - t, outer.size.x + 2 * t, t),
		Rect2(outer.position.x - t, outer.end.y, outer.size.x + 2 * t, t),
		Rect2(outer.position.x - t, outer.position.y, t, outer.size.y),
		Rect2(outer.end.x, outer.position.y, t, outer.size.y),
	]
	for r in rects:
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = r.size
		cs.shape = sh
		cs.position = r.get_center()
		body.add_child(cs)
	add_child(body)
	bounds_body = body


# ------------------------------------------------------------------ backdrop

func _build_backdrop() -> void:
	if projection != &"iso" or map.ambient == &"cave" or play_rect.size == Vector2.ZERO:
		return
	var art: Dictionary = ArtCatalog.backdrop(map.theme)
	var centre: Vector2 = play_rect.get_center()
	# viewport in world px at the widest zoom-out (+ ultrawide headroom) decides how far the layers must reach
	var cover := Vector2(1280.0 / Iso.ZOOM_MIN * 1.6, 720.0 / Iso.ZOOM_MIN * 1.6)
	var sky := Parallax2D.new()
	sky.name = "Sky"
	var s_scale: float = 0.12
	sky.scroll_scale = Vector2(s_scale, s_scale)
	var sky_tex: Texture2D = art["sky"]
	var sky_sprite := Sprite2D.new()
	sky_sprite.texture = sky_tex
	sky_sprite.position = centre * s_scale
	var need: Vector2 = cover + play_rect.size * s_scale * 2.0
	sky_sprite.scale = Vector2(need.x / maxf(sky_tex.get_width(), 1.0), need.y / maxf(sky_tex.get_height(), 1.0))
	sky.add_child(sky_sprite)
	backdrop.add_child(sky)
	var far := Parallax2D.new()
	far.name = "Far"
	var f_scale: float = 0.5
	far.scroll_scale = Vector2(f_scale, f_scale)
	var far_tex: Texture2D = art["far"]
	var tile_px: float = 2048.0 if not bool(art["real"]) else far_tex.get_width() * 1.5
	var sprite_scale: float = tile_px / maxf(far_tex.get_width(), 1.0)
	far.repeat_size = Vector2(tile_px, 0.0)
	far.repeat_times = int(ceil(cover.x / tile_px)) + 2
	var far_sprite := Sprite2D.new()
	far_sprite.texture = far_tex
	far_sprite.scale = Vector2(sprite_scale, sprite_scale)
	far_sprite.centered = false
	far_sprite.position = Vector2(centre.x * f_scale - tile_px * 0.5, centre.y * f_scale + cover.y * 0.05)
	far.add_child(far_sprite)
	backdrop.add_child(far)


# ------------------------------------------------------------------ skirts (R.10)

## One skirt prop per platform-edge cell: SW-facing where the cell below-left (x, y+1) is void, SE-facing where below-right (x+1, y)
## is void, the corner piece where both. They live in Skirts (z -9, NOT y-sorted), never in Objects: a sort tie with an actor
## standing on the edge cell would paint the skirt over the actor.
func _rebuild_skirts() -> void:
	skirt_nodes.clear()
	for child in skirts.get_children():
		skirts.remove_child(child)
		child.queue_free()
	for y in map.height:
		for x in map.width:
			var c := Vector2i(x, y)
			var ch: String = map.ground_at(c)
			if ch.length() == 0 or NO_SKIRT_CHARS.contains(ch):
				continue
			var sw: bool = map.is_void(Vector2i(x, y + 1))
			var se: bool = map.is_void(Vector2i(x + 1, y))
			if not sw and not se:
				continue
			var id: StringName = SKIRT_CORNER if (sw and se) else (SKIRT_SW if sw else SKIRT_SE)
			var art: Dictionary = ArtCatalog.prop(id)
			var spr := Sprite2D.new()
			spr.name = "Skirt_%d_%d" % [x, y]
			spr.texture = art["texture"]
			spr.centered = false
			spr.offset = -(art["pivot"] as Vector2)
			spr.position = Iso.iso_center(c)
			spr.set_meta("skirt", String(id))
			skirts.add_child(spr)
			skirt_nodes[c] = spr


# ------------------------------------------------------------------ growth (addendum amendment 2)

func _collect_growth_cells() -> void:
	_growth_cells.clear()
	var limit := Vector2i(map.width, map.height)
	for ch in map.markers:
		var m: Dictionary = map.markers[ch]
		if str(m.get("marker", "")) != "growth":
			continue
		var stage: int = clampi(int(m.get("stage", 1)), 1, 9)
		# a Dictionary used as an ordered set (O(1) per cell): the cells of a marker and of its object chars, in first-seen order
		var seen: Dictionary = {}
		for c in (_growth_cells.get(stage, []) as Array):
			seen[c] = true
		var problems: Array[String] = []
		for c1 in parse_cells(str(m.get("cells", "")), limit, problems):
			seen[c1] = true
		for c2 in map.find_objects(ch):
			seen[c2] = true
		for problem in problems:
			var msg: String = "growth marker '%s' (stage %d): %s" % [ch, stage, problem]
			if not map.errors.has(msg):
				map.errors.append(msg)
		_growth_cells[stage] = seen.keys()


## "x,y;x,y" and ranges "x0..x1,y0..y1" -> cells (the `cells=` parameter of the growth marker), each cell once, in first-seen order.
## `limit` (the map size in cells) clips every range to the map BEFORE it is expanded, so a mistyped `0..99999999` costs nothing; without a
## limit a text naming more than MAX_PARSED_CELLS cells in one part is refused. Reversed ranges (`8..3`) are swapped. What was clipped,
## refused or not understood is described in `problems` (one entry per part) so the caller can report it; the rest still parses.
static func parse_cells(text: String, limit: Vector2i = Vector2i(-1, -1), problems: Array[String] = []) -> Array[Vector2i]:
	var seen: Dictionary = {}
	var clip: bool = limit.x >= 0 and limit.y >= 0
	for part in text.split(";", false):
		var xy: PackedStringArray = part.split(",", false)
		var xr: PackedInt64Array = _range_of(xy[0]) if xy.size() == 2 else PackedInt64Array()
		var yr: PackedInt64Array = _range_of(xy[1]) if xy.size() == 2 else PackedInt64Array()
		if xr.is_empty() or yr.is_empty():
			problems.append("cells part '%s' is neither x,y nor x0..x1,y0..y1 (whole numbers)" % part.strip_edges())
			continue
		var x0: int = xr[0]
		var x1: int = xr[1]
		var y0: int = yr[0]
		var y1: int = yr[1]
		if clip:
			var cx0: int = maxi(x0, 0)
			var cx1: int = mini(x1, limit.x - 1)
			var cy0: int = maxi(y0, 0)
			var cy1: int = mini(y1, limit.y - 1)
			if cx0 != x0 or cx1 != x1 or cy0 != y0 or cy1 != y1:
				problems.append("cells part '%s' reaches outside the %d x %d map (clipped to the map)" % [part.strip_edges(), limit.x, limit.y])
			x0 = cx0
			x1 = cx1
			y0 = cy0
			y1 = cy1
		elif maxf(maxf(absf(float(x0)), absf(float(x1))), maxf(absf(float(y0)), absf(float(y1)))) > 1.0e9 \
				or (float(x1) - float(x0) + 1.0) * (float(y1) - float(y0) + 1.0) > float(MAX_PARSED_CELLS):     # floats: no 64-bit wrap-around
			problems.append("cells part '%s' names more than %d cells (refused)" % [part.strip_edges(), MAX_PARSED_CELLS])
			continue
		for yy in range(y0, y1 + 1):
			for xx in range(x0, x1 + 1):
				seen[Vector2i(xx, yy)] = true
	var out: Array[Vector2i] = []
	for k in seen.keys():
		out.append(k)
	return out


## "7" -> [7, 7], "3..8" -> [3, 8] (reversed ends are swapped); empty when the text is no whole number or range. Numbers of more
## than 15 digits saturate at +-10^15 (String.to_int() would print an engine error for them), so a typo like 99999999999999999999 is
## just a very large range that the map clips.
static func _range_of(s: String) -> PackedInt64Array:
	var t: String = s.strip_edges()
	var ends: PackedStringArray = t.split("..", false)
	if ends.size() == 2 and ends[0].strip_edges().is_valid_int() and ends[1].strip_edges().is_valid_int():
		var a: int = _whole(ends[0].strip_edges())
		var b: int = _whole(ends[1].strip_edges())
		return PackedInt64Array([mini(a, b), maxi(a, b)])
	if ends.size() == 1 and t.is_valid_int():
		var v: int = _whole(t)
		return PackedInt64Array([v, v])
	return PackedInt64Array()


static func _whole(t: String) -> int:
	var digits: String = t.lstrip("+-")
	if digits.length() > 15:
		return -1000000000000000 if t.begins_with("-") else 1000000000000000
	return t.to_int()


## Highest growth stage the map declares (0 = none).
func max_growth_stage() -> int:
	var hi: int = 0
	for s in _growth_cells:
		hi = maxi(hi, int(s))
	return hi


func growth_cells(stage: int) -> Array:
	return (_growth_cells.get(stage, []) as Array).duplicate()


## Turns the void cells of every growth stage <= `rows` into deck cells (and the others back into void), recomputes the void-rim
## blockers and the skirts (one skirt prop per edge cell, including the right facade along the grown rows), the playable rect,
## the camera limits and the bounds ring. The state is DERIVED (F6 calls it on enter and on home_upgraded); nothing is saved.
func set_growth_stage(rows: int) -> void:
	var want: int = clampi(rows, 0, max_growth_stage())
	var touched: Array[Vector2i] = []
	for stage in _growth_cells:
		var on: bool = int(stage) <= want
		for c in (_growth_cells[stage] as Array):
			var cell: Vector2i = c
			if cell.x < 0 or cell.y < 0 or cell.x >= map.width or cell.y >= map.height:
				continue
			var was_deck: bool = map.ground_at(cell) != "#"
			if on and not was_deck:
				map.set_ground(cell, "d")
				touched.append(cell)
			elif not on and was_deck and _orig_ground[cell.y][cell.x] == "#":
				map.set_ground(cell, "#")
				touched.append(cell)
	growth_stage = want
	if not touched.is_empty():
		var rim: Dictionary = {}
		for cell2 in touched:
			_paint_cell(cell2)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nb := Vector2i(cell2.x + dx, cell2.y + dy)
					if nb.x >= 0 and nb.y >= 0 and nb.x < map.width and nb.y < map.height and map.is_void(nb):
						rim[nb] = true
		for nb2 in rim:
			_set_void_cell(nb2)
		_compute_play_rect()
		_rebuild_skirts()
		_build_bounds()
	growth_changed.emit(growth_stage)


# ------------------------------------------------------------------ objects layer

func _build_objects() -> void:
	for y in map.height:
		for x in map.width:
			var ch: String = map.object_at(Vector2i(x, y))
			if ch == "." or ch == " ":
				continue
			var c := Vector2i(x, y)
			var pos: Vector2 = cell_to_global(c)
			if ch == "@":
				spawns["default"] = pos
			elif map.markers.has(ch):
				_build_marker(ch, map.markers[ch], c, pos)
			elif map.props.has(ch):
				var pd: Dictionary = map.props[ch]
				var node: Node2D = place_prop(str(pd["prop"]), c, pd)
				_track_when(pd, prop_parts(node))
			else:
				unknown_chars[ch] = int(unknown_chars.get(ch, 0)) + 1
	# growth markers can also be declared without any char in the rows (cells= only): nothing to build, state is derived


## Places a prop by its ART id on a cell: the sprite (one Sprite2D, or y-sort strips for big sprites), its solid collider from
## lua/config/props.lua, an additive glow and a PointLight2D when the art / the def carry them. Returns the first sprite node;
## prop_parts(node) gives every sprite node (all strips) plus the collider body of the same prop.
## The object char of a multi-cell prop marks its FRONT cell; the art's pivot sits at the footprint centre.
func place_prop(prop_id: String, cell: Vector2i, params: Dictionary = {}) -> Node2D:
	var def: Dictionary = GameData.prop_def(prop_id)
	var art_id: String = str(def.get("art", prop_id))
	var art: Dictionary = ArtCatalog.prop(StringName(art_id))
	var fp: Vector2i = GameData.footprint_of(prop_id) if def.has("footprint") else (art["footprint"] as Vector2i)
	var is_iso: bool = projection == &"iso"
	var pivot_pos: Vector2 = Iso.iso_footprint_center(cell, fp.x, fp.y) if is_iso else Iso.ortho_center(cell)
	var strips: int = int(def.get("strips", 0))
	var tex: Texture2D = art["texture"]
	var pivot: Vector2 = art["pivot"]
	var nodes: Array[Node2D] = []
	var body: StaticBody2D = _make_collider(def, cell, fp, pivot_pos, prop_id)
	if strips > 0 and is_iso and tex.get_width() > STRIP_W:
		nodes = _make_strips(tex, pivot, pivot_pos, cell, fp, strips, prop_id)
	else:
		var spr := Sprite2D.new()
		spr.name = "%s_%d_%d" % [prop_id, cell.x, cell.y]
		spr.texture = tex
		spr.centered = false
		spr.offset = -pivot
		spr.position = pivot_pos
		if str(art.get("blend", "")) == "add":
			spr.material = Glow.additive_material()
		nodes.append(spr)
	var first: Node2D = nodes[0]
	for n in nodes:
		n.add_to_group("prop")
		n.add_to_group(StringName("prop_%s" % prop_id))
		var g: String = str(def.get("group", ""))
		if g != "":
			n.add_to_group(StringName(g))
		n.set_meta("prop_id", prop_id)
		n.set_meta("cell", cell)
		objects.add_child(n)
	# glow (additive halo) and light ride on the first node; both ramp in with the night factor
	var glow: Dictionary = art.get("glow", {}) as Dictionary
	if not glow.is_empty():
		var halo := Sprite2D.new()
		halo.name = "Glow"
		halo.texture = glow["texture"]
		# A sliced building's first strip has its own sorting origin. Window
		# coordinates belong to the complete image, anchored at the footprint.
		halo.position = pivot_pos + (glow["center"] as Vector2) - pivot - first.position
		var gsize: Vector2 = glow["size"]
		var gt: Texture2D = glow["texture"]
		halo.scale = Vector2(gsize.x / maxf(gt.get_width(), 1.0), gsize.y / maxf(gt.get_height(), 1.0))
		halo.modulate = Color(glow["color"] as Color, 0.0)
		halo.material = Glow.additive_material()
		halo.z_index = 1
		first.add_child(halo)
		_glows.append({"node": halo, "base": 0.9})
	var light_def: Dictionary = GameData.dict_of(def.get("light", {}))
	if not light_def.is_empty():
		var off: Array = GameData.array_of(light_def.get("offset", [0, -60]))
		var l := PointLight2D.new()
		l.name = "Light"
		l.texture = Glow.light_texture()
		l.texture_scale = float(light_def.get("radius", 300)) / 128.0
		l.color = Color.from_string(str(light_def.get("color", "ffd98a")), Color("ffd98a"))
		l.energy = 0.0
		l.position = Vector2(float(off[0]) if off.size() > 0 else 0.0, float(off[1]) if off.size() > 1 else -60.0)
		first.add_child(l)
		_lights.append({"node": l, "base": float(light_def.get("energy", 0.85))})
	# Ground contact belongs below every y-sorted actor, independent of which
	# building strip is nearest. Its pivot is the same footprint centre.
	var contact: Dictionary = art.get("ground", {})
	var ground_contact: Sprite2D = null
	if not contact.is_empty():
		ground_contact = Sprite2D.new()
		ground_contact.name = "%s_GroundContact" % prop_id
		ground_contact.texture = contact["texture"]
		ground_contact.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		ground_contact.centered = false
		ground_contact.offset = -(contact["pivot"] as Vector2)
		ground_contact.position = pivot_pos
		ground_fx.add_child(ground_contact)
	prop_nodes.append({"id": prop_id, "cell": cell, "nodes": nodes, "body": body, "ground": ground_contact})
	if night_factor > 0.0:
		_apply_night()
	return first


## y-sort strips of a big sprite (R.10): strip k covers sprite columns [u0, u1); its centre xc = P.x + (u0 + u1) / 2 - pivot.x gets
## the sort y B.y - squash * |xc - B.x| clamped from below by L.y (left of B) or R.y (right of B), where L, B, R are the left,
## bottom and right corners of Iso.iso_footprint(front, fx, fz). Each strip is a Sprite2D (centered = false) with an AtlasTexture
## region (u0, 0, u1 - u0, H) at position (xc, sort_y) and offset (P + (u0 - pivot.x, -pivot.y)) - position, which draws the
## full sprite unchanged.
func _make_strips(tex: Texture2D, pivot: Vector2, p_pos: Vector2, cell: Vector2i, fp: Vector2i, strips: int, prop_id: String) -> Array[Node2D]:
	var out: Array[Node2D] = []
	var w: int = tex.get_width()
	var h: int = tex.get_height()
	var width: int = maxi(STRIP_W, int(ceil(float(w) / float(strips))))
	var poly: PackedVector2Array = Iso.iso_footprint(cell, fp.x, fp.y)
	var L: Vector2 = poly[3]
	var B: Vector2 = poly[2]
	var R: Vector2 = poly[1]
	var k: int = 0
	var u0: int = 0
	while u0 < w:
		var u1: int = mini(u0 + width, w)
		var xc: float = p_pos.x + float(u0 + u1) * 0.5 - pivot.x
		var sort_y: float = B.y - Iso.squash() * absf(xc - B.x)
		if xc < B.x:
			sort_y = maxf(sort_y, L.y)
		elif xc > B.x:
			sort_y = maxf(sort_y, R.y)
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(u0, 0, u1 - u0, h)
		var s := Sprite2D.new()
		s.name = "%s_%d_%d_strip%d" % [prop_id, cell.x, cell.y, k]
		s.texture = at
		s.centered = false
		s.position = Vector2(xc, sort_y)
		s.offset = (p_pos + Vector2(float(u0) - pivot.x, -pivot.y)) - s.position
		s.set_meta("strip", k)
		s.set_meta("sort_y", sort_y)
		out.append(s)
		k += 1
		u0 = u1
	return out


## The solid StaticBody2D of a prop (layer world), from the `solid` table of the def; null for shape none.
func _make_collider(def: Dictionary, cell: Vector2i, fp: Vector2i, p_pos: Vector2, prop_id: String) -> StaticBody2D:
	var solid: Dictionary = GameData.dict_of(def.get("solid", {}))
	var shape_name: String = str(solid.get("shape", "none"))
	if shape_name == "none":
		return null
	var pts := PackedVector2Array()
	match shape_name:
		"circle":
			var r: float = float(solid.get("radius", 26))
			for i in 12:
				var a: float = TAU * float(i) / 12.0
				pts.append(Iso.to_screen(Vector2(cos(a) * r, sin(a) * r)))
		"footprint":
			if projection == &"iso":
				var poly: PackedVector2Array = Iso.iso_footprint(cell, fp.x, fp.y)
				var centre: Vector2 = (poly[0] + poly[2]) * 0.5
				var ground_pts := PackedVector2Array()
				for p in poly:
					ground_pts.append(Iso.to_ground(p - centre))
				var pad: float = float(solid.get("pad", 0))
				var grown: Array = Geometry2D.offset_polygon(ground_pts, pad, Geometry2D.JOIN_MITER) if pad != 0.0 else [ground_pts]
				if not grown.is_empty():
					for p2 in grown[0]:
						pts.append(Iso.to_screen(p2))
			else:
				var hw: float = Iso.ORTHO_W * 0.5 * fp.x
				var hh: float = Iso.ORTHO_H * 0.5 * fp.y
				pts = PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])
		"bar":
			var along: Vector2 = Vector2(1, 1).normalized() if str(solid.get("along", "x")) == "x" else Vector2(-1, 1).normalized()
			var across: Vector2 = Vector2(-along.y, along.x)
			var half_len: float = float(solid.get("length", 90)) * 0.5
			var half_w: float = float(solid.get("width", 10)) * 0.5
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var cv: Vector2 = corner
				pts.append(Iso.to_screen(along * half_len * cv.x + across * half_w * cv.y))
	if pts.size() < 3:
		return null
	var body := StaticBody2D.new()
	body.name = "Solid_%s_%d_%d" % [prop_id, cell.x, cell.y]
	body.collision_layer = Iso.LAYER_WORLD
	body.collision_mask = 0
	body.position = p_pos
	var cs := CollisionShape2D.new()
	var sh := ConvexPolygonShape2D.new()
	sh.points = pts
	cs.shape = sh
	body.add_child(cs)
	body.add_to_group("prop_body")
	colliders.add_child(body)
	return body


## Everything one placed prop is made of: ALL its sprite nodes (every y-sort strip) plus its StaticBody2D collider. `node` is any
## sprite node of the prop (place_prop returns the first), including its ground contact. A `when=` condition switches all parts: the strips of a big
## sprite hide together and the solid body leaves the world layer, otherwise a hidden house stays an invisible wall.
## Returns [] when the node does not belong to a placed prop.
func prop_parts(node: Node) -> Array:
	if node == null:
		return []
	for rec in prop_nodes:
		if node in (rec["nodes"] as Array) or node == rec.get("ground"):
			var parts: Array = (rec["nodes"] as Array).duplicate()
			if rec.get("ground") != null:
				parts.append(rec["ground"])
			if rec["body"] != null:
				parts.append(rec["body"])
			return parts
	return []


## Frees a prop placed by place_prop (its sprites, strips, ground contact, collider). Returns whether the node belonged to a placed prop.
func remove_prop(node: Node) -> bool:
	if node == null:
		return false
	for i in prop_nodes.size():
		var rec: Dictionary = prop_nodes[i]
		if node in (rec["nodes"] as Array) or node == rec.get("ground"):
			for n in (rec["nodes"] as Array):
				_forget_glows(n)
				(n as Node).queue_free()
			if rec.get("ground") != null:
				(rec["ground"] as Node).queue_free()
			if rec["body"] != null:
				(rec["body"] as Node).queue_free()
			prop_nodes.remove_at(i)
			return true
	return false


func _forget_glows(n: Node) -> void:
	_glows = _glows.filter(func(g: Dictionary) -> bool: return not n.is_ancestor_of(g["node"] as Node))
	_lights = _lights.filter(func(l: Dictionary) -> bool: return not n.is_ancestor_of(l["node"] as Node))


# ------------------------------------------------------------------ markers

func find_markers(type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in markers:
		if str(m["type"]) == type:
			out.append(m)
	return out


## Number of marker occurrences of a type that got a node (built in or through a handler script).
func handled_count(type: String) -> int:
	var n: int = 0
	for m in markers:
		if str(m["type"]) == type and (m["node"] != null or bool(m.get("builtin_data", false))):
			n += 1
	return n


func _build_marker(ch: String, m: Dictionary, c: Vector2i, pos: Vector2) -> void:
	var type: String = str(m["marker"])
	var rec: Dictionary = {"type": type, "params": m, "cell": c, "pos": pos, "char": ch, "node": null, "nodes": []}
	markers.append(rec)
	# a per-area override (the world spike's way) wins over everything
	if marker_handlers.has(type):
		var made: Variant = (marker_handlers[type] as Callable).call(m, pos, c, self)
		if made is Node:
			_adopt_marker_node(rec, made as Node, pos)
			return
	var h: Dictionary = resolve_handler(type)
	match str(h["kind"]):
		"script":
			var node: Node = _make_from_script(h, m, pos, c)
			if node != null:
				_adopt_marker_node(rec, node, pos)
				return
			_skip_marker(type)
		"builtin":
			_build_builtin(rec, type, m, c, pos)
		_:
			_skip_marker(type)


func _skip_marker(type: String) -> void:
	skipped_markers[type] = int(skipped_markers.get(type, 0)) + 1


func _make_from_script(h: Dictionary, m: Dictionary, pos: Vector2, c: Vector2i) -> Node:
	var s: Script = h["script"]
	match str(h["mode"]):
		"create_marker":
			return s.call("create_marker", m, pos, c, self) as Node
		"create2":
			return s.call("create", m, pos) as Node
		"create1":
			return s.call("create", m) as Node
		"setup_marker":
			var inst: Object = s.new()
			if inst is Node:
				inst.call("setup_marker", m, pos, c, self)
				return inst as Node
			if inst != null and not (inst is RefCounted):
				inst.free()
	return null


func _adopt_marker_node(rec: Dictionary, node: Node, pos: Vector2) -> void:
	if node.get_parent() == null:
		objects.add_child(node)
	if node is Node2D and (node as Node2D).position == Vector2.ZERO:
		(node as Node2D).position = to_local(pos)
	rec["node"] = node
	rec["nodes"] = [node]
	_track_when(rec["params"] as Dictionary, [node])


func _build_builtin(rec: Dictionary, type: String, m: Dictionary, c: Vector2i, pos: Vector2) -> void:
	match type:
		"spawn":
			spawns[str(m.get("name", "default"))] = pos
			rec["builtin_data"] = true
		"growth":
			rec["builtin_data"] = true
		"warp":
			var wp := Warp2D.new()
			wp.setup(m, self, c)
			wp.position = to_local(pos)
			triggers.add_child(wp)
			rec["node"] = wp
			var nodes: Array = [wp]
			if str(m.get("prop", "")) != "":
				var gate: Node2D = place_prop(str(m["prop"]), c)
				nodes.append_array(prop_parts(gate))
			rec["nodes"] = nodes
			_track_when(m, nodes)
		"sign":
			var prop_id: String = str(m.get("prop", "signpost"))
			var sg: Node2D = place_prop(prop_id, c)
			var it := Interactable2D.new()
			it.name = "Sign_%d_%d" % [c.x, c.y]
			it.prompt_key = "UI_READ"
			it.radius = Vector2(70, 36)
			it.position = to_local(pos)
			var text_key: String = str(m.get("text", ""))
			it.interacted.connect(func(_p: Node) -> void: EventBus.whisper_requested.emit(text_key))
			objects.add_child(it)
			rec["node"] = it
			var sign_nodes: Array = [it]
			sign_nodes.append_array(prop_parts(sg))
			rec["nodes"] = sign_nodes
			_track_when(m, sign_nodes)
		"bed":
			var bed := Interactable2D.new()
			bed.name = "Bed"
			bed.prompt_key = "UI_SLEEP"
			bed.radius = Vector2(80, 40)
			bed.position = to_local(pos)
			bed.interacted.connect(func(_p: Node) -> void: get_tree().call_group("world_2d", "sleep"))
			objects.add_child(bed)
			rec["node"] = bed
			rec["nodes"] = [bed]
			_track_when(m, [bed])
		"quest_spot":
			var spot_nodes: Array = []
			if str(m.get("prop", "")) != "":
				spot_nodes.append_array(prop_parts(place_prop(str(m["prop"]), c)))
			var spot := Interactable2D.new()
			spot.name = "QuestSpot_%d_%d" % [c.x, c.y]
			spot.prompt_key = str(m.get("prompt", "WORLD_PROMPT_USE"))
			spot.radius = Vector2(70, 36)
			spot.position = to_local(pos)
			spot.interacted.connect(_on_quest_spot.bind(m))
			objects.add_child(spot)
			spot_nodes.append(spot)
			rec["node"] = spot
			rec["nodes"] = spot_nodes
			_track_when(m, spot_nodes)
		"light":
			var ln: Node2D = _make_light(m, pos)
			rec["node"] = ln
			rec["nodes"] = [ln]
			_track_when(m, [ln])


func _make_light(m: Dictionary, pos: Vector2) -> Node2D:
	var kind: String = str(m.get("kind", "lantern"))
	var radius: float = float(m.get("r", 300.0 if kind == "lantern" else 170.0))
	var col: Color = Color.from_string(str(m.get("color", "ffd98a" if kind == "lantern" else "6fd6c4")), Color("ffd98a"))
	var holder := Node2D.new()
	holder.name = "Light_%s" % kind
	holder.position = to_local(pos)
	var l := PointLight2D.new()
	l.texture = Glow.light_texture()
	l.texture_scale = radius / 128.0
	l.color = col
	l.energy = 0.0
	l.position = Vector2(0, -float(m.get("h", 40)))
	holder.add_child(l)
	_lights.append({"node": l, "base": 0.9 if kind == "lantern" else 0.8})
	var halo := Sprite2D.new()
	halo.texture = Glow.halo_texture()
	halo.scale = Vector2.ONE * (radius / 128.0) * 0.5
	halo.position = l.position
	halo.modulate = Color(col, 0.0)
	halo.material = Glow.additive_material()
	holder.add_child(halo)
	_glows.append({"node": halo, "base": 0.55})
	objects.add_child(holder)
	var prop_id := StringName(str(m.get("prop", "")))
	if prop_id != &"":
		var art: Dictionary = ArtCatalog.prop(prop_id)
		var sprite := Sprite2D.new()
		sprite.name = "PaintedLight"
		sprite.texture = art["texture"] as Texture2D
		sprite.centered = false
		sprite.offset = -(art["pivot"] as Vector2)
		holder.add_child(sprite)
	return holder


## quest_spot interaction: the quest manager owns eligibility, resource costs and completion.
func _on_quest_spot(_player: Node, m: Dictionary) -> void:
	var qm: Node = GameData.autoload("QuestManager")
	var quest := StringName(str(m.get("quest", "")))
	var objective := StringName(str(m.get("objective", "")))
	if qm == null or quest == &"":
		return
	var transactional: bool = qm.has_method("can_complete_manual")
	if transactional and not bool(qm.call("can_complete_manual", quest, objective)):
		return
	var needs: Dictionary = {}
	for part in str(m.get("needs", "")).split(",", false):
		var kv: PackedStringArray = part.split(":", false)
		if kv.size() != 2 or not kv[1].is_valid_int() or int(kv[1]) <= 0:
			return
		needs[kv[0]] = int(needs.get(kv[0], 0)) + int(kv[1])
	var eco: Node = GameData.eco()
	if eco == null:
		return
	if not bool(eco.call("has_items", needs)):
		EventBus.whisper_requested.emit("WORLD_NEEDS_ITEMS")
		return
	var consume: bool = str(m.get("consume", "0")) == "1"
	if transactional:
		qm.call("complete_manual", quest, objective, needs, consume)
	else:
		# Retain the documented adapter for older quest providers and recorder stubs.
		if consume and not bool(eco.call("remove_items", needs)):
			return
		if qm.has_method("complete_manual"):
			qm.call("complete_manual", quest, objective)
		elif qm.has_method("update_objective"):
			qm.call("update_objective", quest, objective, 1)


# ------------------------------------------------------------------ when= conditions

## Registers nodes behind a `when=` condition and applies it at once.
func _track_when(params: Dictionary, nodes: Array) -> void:
	var w: String = str(params.get("when", ""))
	if w == "" or nodes.is_empty():
		return
	_has_flag_when = _has_flag_when or w.begins_with("flag:")
	var rec: Dictionary = {"nodes": nodes, "when": w, "active": true, "is_flag": w.begins_with("flag:")}
	_when_nodes.append(rec)
	_apply_when(rec)
	if _has_flag_when:
		set_process(true)                     # only flag: whens need the _process poll; quest / night arrive by signal


static func evaluate_when(spec: String) -> bool:
	## quest:<id> (active) | done:<id> | flag:<name> | night; an empty spec is true.
	if spec == "":
		return true
	var kind: String = spec.get_slice(":", 0)
	var arg: String = spec.get_slice(":", 1) if spec.contains(":") else ""
	match kind:
		"quest":
			var qm: Node = GameData.autoload("QuestManager")
			return qm != null and qm.has_method("is_active") and bool(qm.call("is_active", StringName(arg)))
		"done":
			var qm2: Node = GameData.autoload("QuestManager")
			return qm2 != null and qm2.has_method("is_completed") and bool(qm2.call("is_completed", StringName(arg)))
		"flag":
			var gm: Node = GameData.gm()
			if gm == null:
				return false
			return _truthy(gm.call("get_flag", StringName(arg), false))
		"night":
			var tm: Node = GameData.tm()
			return tm != null and tm.has_method("is_night") and bool(tm.call("is_night"))
	return true


## A world flag counts as set when it is true, a non-zero number or a non-empty string.
static func _truthy(v: Variant) -> bool:
	match typeof(v):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return v
		TYPE_INT:
			return v != 0
		TYPE_FLOAT:
			return v != 0.0
		TYPE_STRING, TYPE_STRING_NAME:
			return str(v) != ""
	return true


## Re-evaluates every `when=` of this area (called on enter and on quest / clock / flag changes).
func refresh_when() -> void:
	for rec in _when_nodes:
		_apply_when(rec)


func _apply_when(rec: Dictionary) -> void:
	var on: bool = evaluate_when(str(rec["when"]))
	rec["active"] = on
	for n in (rec["nodes"] as Array):
		if is_instance_valid(n):
			_set_node_active(n as Node, on)


func _set_node_active(n: Node, on: bool) -> void:
	if n.has_method("set_enabled"):
		n.call("set_enabled", on)
		return
	if n is CanvasItem:
		(n as CanvasItem).visible = on
	n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	_set_collision_enabled(n, on)


func _set_collision_enabled(n: Node, on: bool) -> void:
	if n is CollisionObject2D:
		var co: CollisionObject2D = n
		if on:
			if co.has_meta("when_layer"):
				co.collision_layer = int(co.get_meta("when_layer"))
		else:
			if not co.has_meta("when_layer"):
				co.set_meta("when_layer", co.collision_layer)
			co.collision_layer = 0
	for ch in n.get_children():
		_set_collision_enabled(ch, on)


func when_active_count() -> int:
	var n: int = 0
	for rec in _when_nodes:
		if bool(rec["active"]):
			n += 1
	return n


func when_total_count() -> int:
	return _when_nodes.size()


# ------------------------------------------------------------------ night glow, water, lifecycle

## 0 = day, 1 = full night: fades the additive glow sprites and the PointLights in (called by WorldRoot2D from DayNight.glow_changed).
func set_night_factor(f: float) -> void:
	night_factor = clampf(f, 0.0, 1.0)
	_apply_night()


func _apply_night() -> void:
	for g in _glows:
		var n: CanvasItem = g["node"]
		if is_instance_valid(n):
			var col: Color = n.modulate
			col.a = night_factor * float(g["base"])
			n.modulate = col
			n.visible = night_factor > 0.004
	for l in _lights:
		var pl: PointLight2D = l["node"]
		if is_instance_valid(pl):
			pl.energy = night_factor * float(l["base"])
			pl.visible = night_factor > 0.004


## The visible water frame (0..3).
func water_frame() -> int:
	return _water_frame


func set_water_frame(i: int) -> void:
	_water_frame = posmod(i, maxi(water_layers.size(), 1))
	for k in water_layers.size():
		water_layers[k].visible = k == _water_frame


func _enter_tree() -> void:
	if _hooked:
		return
	_hooked = true
	# quests, the clock and generic game events can change a `when=`; flags are polled in _process (they have no signal)
	EventBus.quest_accepted.connect(_on_quest_event)
	EventBus.quest_completed.connect(_on_quest_event)
	EventBus.quest_failed.connect(_on_quest_event)
	EventBus.day_started.connect(_on_day_event)
	EventBus.time_of_day_changed.connect(_on_clock_event)
	EventBus.game_event.connect(_on_game_event)
	if map != null:
		refresh_when()


func _exit_tree() -> void:
	if not _hooked:
		return
	_hooked = false
	EventBus.quest_accepted.disconnect(_on_quest_event)
	EventBus.quest_completed.disconnect(_on_quest_event)
	EventBus.quest_failed.disconnect(_on_quest_event)
	EventBus.day_started.disconnect(_on_day_event)
	EventBus.time_of_day_changed.disconnect(_on_clock_event)
	EventBus.game_event.disconnect(_on_game_event)


func _on_quest_event(_quest_id: StringName) -> void:
	refresh_when()


func _on_day_event(_day: int, _season: StringName) -> void:
	refresh_when()


func _on_clock_event(_hour: int, _minute: int) -> void:
	for rec in _when_nodes:
		if str(rec["when"]) == "night":
			_apply_when(rec)


func _on_game_event(_event_name: StringName, _payload: Dictionary) -> void:
	refresh_when()


func _process(delta: float) -> void:
	if _has_water:
		_water_t += delta
		if _water_t >= WATER_PERIOD:
			_water_t -= WATER_PERIOD
			set_water_frame(_water_frame + 1)
	if _has_flag_when:
		_poll_t += delta
		if _poll_t >= FLAG_POLL_PERIOD:
			_poll_t = 0.0
			for rec in _when_nodes:
				if rec.get("is_flag", false):
					_apply_when(rec)


## Called by WorldRoot2D after the player is put into the area.
func on_enter() -> void:
	refresh_when()
	_apply_night()
