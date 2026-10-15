extends RefCounted
## Validate the effective runtime pack, rather than only the original generator's exports.
const SECTION := "art_world_style"
const TIMEOUT_S := 120.0
const PACK := "res://assets/iso_props/painted_world/"

func run(t) -> void:
	ArtCatalog.reset()
	CityData.clear_cache()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACK + "props.json"))
	var checked := 0
	for id in manifest:
		if str(id).begins_with("_"):
			continue
		var record: Dictionary = manifest[id]
		var art: Dictionary = ArtCatalog.prop(StringName(id))
		var texture: Texture2D = art["texture"]
		var size: Array = record["size"]
		var source := str(record.get("illustration", ""))
		t.check("effective_%s" % id, bool(art["real"]) and texture.resource_path.begins_with(PACK)
			and texture.get_width() == int(size[0]) and texture.get_height() == int(size[1])
			and FileAccess.file_exists("res://" + source), "runtime texture, dimensions and painted master agree")
		checked += 1
	t.check("major_world_assets_covered", checked >= 85, "city structure, huts, details and forest crowns/landmarks")
	var far: Texture2D = ArtCatalog.backdrop(&"treetop")["far"]
	t.check("painted_city_backdrop", far.resource_path.begins_with(PACK), "distant trees use the same painted nature source")
	var city: Dictionary = CityData.city_props()
	var uploaded_bytes := 0.0
	for id in city:
		if str(id).begins_with("_") or not (city[id] is Dictionary):
			continue
		var texture: Texture2D = ArtCatalog.prop(StringName(id))["texture"]
		uploaded_bytes += _upload_bytes(texture)
	var backdrop: Dictionary = ArtCatalog.backdrop(&"treetop")
	uploaded_bytes += _upload_bytes(backdrop["sky"]) + _upload_bytes(backdrop["far"])
	t.check("effective_city_texture_budget", uploaded_bytes <= 70.0e6,
		"%.1f MB RGBA8 including imported mipmaps; existing budget 70 MB" % (uploaded_bytes / 1.0e6))
	for id in ["foliage_front_a", "foliage_front_b"]:
		var texture: Texture2D = ArtCatalog.prop(StringName(id))["texture"]
		var im := Image.new()
		im.load_webp_from_buffer(FileAccess.get_file_as_bytes(texture.resource_path))
		var cut := false
		for x in im.get_width():
			cut = cut or im.get_pixel(x, 0).a > 0.0 or im.get_pixel(x, im.get_height() - 1).a > 0.0
		for y in im.get_height():
			cut = cut or im.get_pixel(0, y).a > 0.0 or im.get_pixel(im.get_width() - 1, y).a > 0.0
		t.check("natural_edge_%s" % id, not cut, "whole leaf silhouettes fit inside the canvas without rectangular cuts")
	for id in city:
		if str(id).begins_with("_") or not (city[id] is Dictionary) or str(city[id].get("kind", "")) != "hut":
			continue
		var hut: Dictionary = city[id]
		var night: Dictionary = city[str(hut["night"])]
		var offset: Array = hut["night_offset"]
		var pivot: Array = hut["pivot"]
		var np: Array = night["pivot"]
		t.check("night_anchor_%s" % id, is_equal_approx(float(np[0]), float(pivot[0]) - float(offset[0]))
			and is_equal_approx(float(np[1]), float(pivot[1]) - float(offset[1])), "glow is derived from the current painted windows")
	var stone: Dictionary = ArtCatalog.prop_metadata(&"runestone_active")
	var glow: Dictionary = ArtCatalog.prop_metadata(&"rune_glow")
	t.check("rune_glow_anchor", stone["size"] == glow["size"] and stone["pivot"] == glow["pivot"],
		"the additive carved rune uses the current stone's canvas and pivot")

func _upload_bytes(texture: Texture2D) -> float:
	var settings := ConfigFile.new()
	settings.load(texture.resource_path + ".import")
	var mips: bool = settings.get_value("params", "mipmaps/generate", false)
	return float(texture.get_width() * texture.get_height()) * 4.0 * (4.0 / 3.0 if mips else 1.0)
