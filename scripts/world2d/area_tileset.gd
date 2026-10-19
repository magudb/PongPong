class_name AreaTileSet
extends RefCounted
## Builds the runtime TileSets (iso diamond / ortho rectangle) from the ART CONTRACT (plan 3.7, 6.2), through ArtCatalog.
##
## iso   TileSet.TILE_SHAPE_ISOMETRIC + TILE_LAYOUT_DIAMOND_DOWN (the default STACKED is wrong), tile_size 128 x 76, one
##       TileSetAtlasSource per terrain with texture_region_size = the atlas cell (144 x 84, overscan 1.4 px), periodic
##       4 x 4 variants: atlas coords of a map cell = Vector2i(cell.x % 4, cell.y % 4) (water: 2 x 2).
## ortho TILE_SHAPE_SQUARE, tile_size 96 x 56, the same trick; wall props become single y-sorted tiles (y_sort_origin = +H/2).
## Physics layers of BOTH TileSets: layer 0 -> collision layer 128 "ground_block" (water, bog, the void rim: walkers are
## blocked, fliers pass), layer 1 -> collision layer 1 "world" (solid walls: blocks everybody).
## Source 0 is always the invisible BLOCKER tile of the void rim; terrain sources are added lazily (ArtCatalog paints / loads a
## terrain only when an area asks for it), so building the farm never paints the forest.

const SRC_BLOCKER := 0
const LAYER_GROUND_BLOCK := 128   # bit value of project layer 8
const LAYER_WORLD := 1            # bit value of project layer 1

## Terrain ids the IsoArea builder maps ground chars to (P22's art_environment test checks them against tiles.json).
const ISO_TERRAINS: Array[StringName] = [&"grass", &"grass_flowers", &"grass_hyggebyen", &"grass_hyggebyen_flowers", &"soil_tilled",
	&"soil_watered", &"path_dirt", &"deck_farm", &"deck_hyggebyen", &"cobble_hyggebyen", &"forest_floor", &"forest_floor_glow",
	&"void_haze", &"water_0", &"water_1", &"water_2", &"water_3"]
const ORTHO_TERRAINS: Array[StringName] = [&"forest_floor_o", &"forest_floor_glow_o", &"moss_path_o", &"bog_o", &"cave_floor_o",
	&"crystal_floor_o", &"wall_void_o"]
## Wall props (assets/iso_props/*.png, props.json `proj: ortho`) the builder places for the `W` ground char.
const WALL_PROPS: Array[StringName] = [&"forest_wall_a", &"forest_wall_b", &"forest_wall_c", &"cave_wall_a", &"cave_wall_b"]
const WATER_FRAMES: Array[StringName] = [&"water_0", &"water_1", &"water_2", &"water_3"]
## Terrains whose tiles carry the ground_block collision polygon (only the FIRST water frame: physics on layer 0 only).
const BLOCKING_TERRAINS: Array[StringName] = [&"water_0", &"bog_o"]

static var _sets: Dictionary = {}   # projection -> {"tileset": WeakRef, "sources": {id: source_id}, "projection": ..., "build_ms": int}
static var _blank: Dictionary = {}  # "WxH" -> ImageTexture


## {tileset, sources, projection, build_ms}. `sources` fills up as terrains are requested (source_for).
static func get_set(projection: StringName) -> Dictionary:
	var key: StringName = &"ortho" if projection == &"ortho" else &"iso"
	if _sets.has(key):
		var stored: Dictionary = _sets[key]
		var live: TileSet = stored.tileset.get_ref()
		if live != null:
			var resident := stored.duplicate()
			resident.tileset = live
			return resident
	var t0: int = Time.get_ticks_msec()
	var ts: TileSet = _make_tileset(key)
	var res: Dictionary = {"tileset": ts, "sources": {}, "projection": key, "build_ms": 0}
	_add_blocker(ts, key)
	res["build_ms"] = Time.get_ticks_msec() - t0
	# The active/parked areas own their TileMaps and atlas textures. Leaving
	# the last area of a projection must release that biome's terrain sheets.
	var stored := res.duplicate()
	stored.tileset = weakref(ts)
	_sets[key] = stored
	return res


static func tile_set(projection: StringName) -> TileSet:
	return get_set(projection)["tileset"]


static func reset() -> void:
	_sets.clear()


static func _tile_px(projection: StringName) -> Vector2i:
	return Vector2i(Iso.ORTHO_W, Iso.ORTHO_H) if projection == &"ortho" else Vector2i(Iso.TILE_W, Iso.TILE_H)


static func _make_tileset(projection: StringName) -> TileSet:
	var ts := TileSet.new()
	if projection == &"ortho":
		ts.tile_shape = TileSet.TILE_SHAPE_SQUARE
	else:
		ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
		ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = _tile_px(projection)
	ts.add_physics_layer()                       # 0 ground_block
	ts.set_physics_layer_collision_layer(0, LAYER_GROUND_BLOCK)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_physics_layer()                       # 1 world
	ts.set_physics_layer_collision_layer(1, LAYER_WORLD)
	ts.set_physics_layer_collision_mask(1, 0)
	return ts


static func diamond_points() -> PackedVector2Array:
	var w: int = Iso.TILE_W
	var h: int = Iso.TILE_H
	return PackedVector2Array([Vector2(0, -h * 0.5), Vector2(w * 0.5, 0), Vector2(0, h * 0.5), Vector2(-w * 0.5, 0)])


static func rect_points() -> PackedVector2Array:
	var w: int = Iso.ORTHO_W
	var h: int = Iso.ORTHO_H
	return PackedVector2Array([Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5, -h * 0.5), Vector2(w * 0.5, h * 0.5), Vector2(-w * 0.5, h * 0.5)])


static func _add_poly(td: TileData, layer: int, pts: PackedVector2Array) -> void:
	td.add_collision_polygon(layer)
	td.set_collision_polygon_points(layer, 0, pts)


static func _blank_texture(size: Vector2i) -> ImageTexture:
	var key: String = "%dx%d" % [size.x, size.y]
	if not _blank.has(key):
		_blank[key] = PlaceholderArt.transparent_texture(size.x, size.y)
	return _blank[key]


static func _add_blocker(ts: TileSet, projection: StringName) -> void:
	var size: Vector2i = _tile_px(projection)
	var src := TileSetAtlasSource.new()
	src.texture = _blank_texture(size)
	src.texture_region_size = size
	src.create_tile(Vector2i(0, 0))
	ts.add_source(src, SRC_BLOCKER)
	var td: TileData = src.get_tile_data(Vector2i(0, 0), 0)
	_add_poly(td, 0, rect_points() if projection == &"ortho" else diamond_points())


## The source ids of the live TileSet of a projection, read without building get_set()'s resident dictionary ({} once the set is gone).
static func _live_sources(projection: StringName) -> Dictionary:
	var stored: Variant = _sets.get(&"ortho" if projection == &"ortho" else &"iso")
	if stored is Dictionary and ((stored as Dictionary)["tileset"] as WeakRef).get_ref() != null:
		return (stored as Dictionary)["sources"]
	return {}


## The source id of a terrain (added on first use). Unknown ids still get a source (ArtCatalog serves a placeholder).
static func source_for(projection: StringName, terrain_id: StringName) -> int:
	var live: Dictionary = _live_sources(projection)
	if live.has(terrain_id):
		return live[terrain_id]
	var set_data: Dictionary = get_set(projection)
	var sources: Dictionary = set_data["sources"]
	if sources.has(terrain_id):
		return sources[terrain_id]
	var ts: TileSet = set_data["tileset"]
	var info: Dictionary = ArtCatalog.terrain(terrain_id)
	var cell: Vector2i = info["cell"]
	var variants: Vector2i = info["variants"]
	var src := TileSetAtlasSource.new()
	src.texture = info["texture"]
	src.texture_region_size = cell
	var blocking: bool = terrain_id in BLOCKING_TERRAINS
	var is_ortho: bool = projection == &"ortho"
	for j in variants.y:
		for i in variants.x:
			src.create_tile(Vector2i(i, j))
	# the source joins the TileSet BEFORE its tiles get physics polygons (the layer count comes from the TileSet)
	var sid: int = ts.add_source(src)
	if blocking:
		for j in variants.y:
			for i in variants.x:
				var td: TileData = src.get_tile_data(Vector2i(i, j), 0)
				_add_poly(td, 0, rect_points() if is_ortho else diamond_points())
	sources[terrain_id] = sid
	return sid


## The atlas coordinate a map cell uses in a terrain's atlas (periodic).
static func atlas_coords_for(terrain_id: StringName, cell: Vector2i) -> Vector2i:
	var info: Dictionary = ArtCatalog.terrain(terrain_id)
	return Iso.atlas_coords(cell, info["variants"])


## A source holding ONE tile made of a wall prop (ortho walls): y-sorted at the cell's bottom edge, solid on layer `world`.
## Returns the source id; the tile sits at atlas coords (0, 0).
static func wall_source_for(prop_id: StringName) -> int:
	var key := StringName("wall:%s" % prop_id)
	var live: Dictionary = _live_sources(&"ortho")
	if live.has(key):
		return live[key]
	var set_data: Dictionary = get_set(&"ortho")
	var sources: Dictionary = set_data["sources"]
	if sources.has(key):
		return sources[key]
	var ts: TileSet = set_data["tileset"]
	var art: Dictionary = ArtCatalog.prop(prop_id)
	var tex: Texture2D = art["texture"]
	var size := Vector2i(tex.get_width(), tex.get_height())
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = size
	src.create_tile(Vector2i(0, 0))
	var sid: int = ts.add_source(src)
	var td: TileData = src.get_tile_data(Vector2i(0, 0), 0)
	var pivot: Vector2 = art["pivot"]
	# texture_origin is SUBTRACTED: moving the pivot (ground origin) onto the tile centre needs pivot - region centre
	td.texture_origin = Vector2i((pivot - Vector2(size) * 0.5).round())
	td.y_sort_origin = Iso.ORTHO_H / 2
	_add_poly(td, 1, rect_points())
	sources[key] = sid
	return sid
