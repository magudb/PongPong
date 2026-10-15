class_name PaintedInteriorArt
extends RefCounted
## Painted kit + furnishing studies. Gameplay owns doors, placed inventory and upgrades.
const DATA := "res://assets/data/interiors/painted.json"
const PACK := "res://assets/iso_props/painted_interiors/"
static var _data: Dictionary = {}

static func _load_data() -> void:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA)) as Dictionary

static func room_ids() -> Array[String]:
	_load_data()
	var ids: Array[String] = []
	for id in _data["rooms"]:
		ids.append(str(id))
	ids.sort()
	return ids

static func room(id: String) -> Dictionary:
	_load_data()
	return (_data["rooms"].get(id, {}) as Dictionary).duplicate(true)

static func footprint(asset_id: String) -> Vector2i:
	var rec: Dictionary = ArtCatalog.prop_metadata(StringName(asset_id))
	var size: Array = rec.get("footprint", [0, 0])
	return Vector2i(int(size[0]), int(size[1]))

static func item_cells(item: Dictionary) -> Array[Vector2i]:
	var first: Array = item["cell"]
	var fp := footprint(str(item["asset"]))
	var cells: Array[Vector2i] = []
	for y in fp.y:
		for x in fp.x:
			cells.append(Vector2i(int(first[0]) + x, int(first[1]) + y))
	return cells

static func item_position(item: Dictionary) -> Vector2:
	var cells := item_cells(item)
	if cells.is_empty():
		var cell: Array = item["cell"]
		var first := Vector2i(int(cell[0]), int(cell[1]))
		var rec: Dictionary = ArtCatalog.prop_metadata(StringName(item["asset"]))
		if rec.has("ground_span"):
			var span: Array = rec["ground_span"]
			var last := first + Vector2i(int(span[0]) - 1, int(span[1]) - 1)
			return (Iso.iso_center(first) + Iso.iso_center(last)) * .5
		return Iso.iso_center(first) - Vector2(0, float(item.get("height", 0)))
	var pos := Vector2.ZERO
	for cell in cells:
		pos += Iso.iso_center(cell)
	return pos / float(cells.size())
