extends RefCounted
## The `@builder` entry point of a levelled area built straight from data/traetoppen/traetoppen.json with LevelStage's stand-in art
## (package V3-levels). A header-only map points at it:
##
##   @id _levels_demo   @projection iso   @ambient farm   @zone traetoppen   @flight false   @zoom 0.4  @zoom_min 0.2  @zoom_max 0.7
##   @builder res://scripts/world2d/levels/level_area_builder.gd          (optional:  @city res://data/traetoppen/traetoppen.json)
##
## The windowed probes of this package and the section city_levels use it. V4's CityBuilder (res://scripts/traetoppen/city_builder.gd) is the
## real builder of the area `traetoppen`: it calls LevelStage.build(...) itself with the real art, markers and landmarks.
## IsoArea calls `build(area, header)` on the script (static); a data file that cannot be read leaves `area.builder_error` and an empty area.

const DEFAULT_CITY := "res://data/traetoppen/traetoppen.json"


static func build(area: IsoArea, header: Dictionary) -> void:
	var extra: Dictionary = LuaData.dict(header.get("extra", {}))
	var path: String = str(extra.get("city", DEFAULT_CITY))
	var data: Dictionary = LevelRegistry.load_data(path)
	if data.is_empty():
		area.builder_error = "levels: %s" % LevelRegistry.last_error
		return
	LevelStage.build(area, data, {})
