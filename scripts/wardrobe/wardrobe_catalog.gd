class_name WardrobeCatalog
extends RefCounted
## Painted garment geometry; inventory, exclusions and perks stay in Lua/manager.
const ROOT := "res://assets/wardrobe/"
static var _data: Dictionary = {}
static var _textures: Dictionary = {}
static var _empty: Texture2D

static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(ROOT + "manifest.json"):
		_data = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
	return _data

static func body(id: String) -> Dictionary:
	return data().get("bodies", {}).get(id.trim_suffix("_base"), {})

static func resolve(id: String, item: Variant) -> Dictionary:
	var definition := ItemKinds.def(item)
	var art: Dictionary = definition.get("art", {})
	var fitted := body(id)
	for family in [str(art.get("layer", "")), str(art.get("fallback", ""))]:
		if fitted.get("layers", {}).has(family):
			return {"family": family, "file": fitted.layers[family], "source_palette": fitted.get("source_palettes", {}).get(family, data().designs[family].source_palette)}
	return {}

static func supports(id: String, item: Variant) -> bool:
	return not resolve(id, item).is_empty()

static func texture(file: String) -> Texture2D:
	if file == "":
		return empty_texture()
	if _textures.has(file):
		var retained: Texture2D = _textures[file].get_ref()
		if retained != null:
			return retained
	var result := load(ROOT + file) as Texture2D
	if result != null:
		_textures[file] = weakref(result)
	return result

static func empty_texture() -> Texture2D:
	if _empty == null:
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		_empty = ImageTexture.create_from_image(image)
	return _empty
