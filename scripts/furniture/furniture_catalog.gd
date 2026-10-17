class_name FurnitureCatalog
extends RefCounted
## Shared content and painted-art records. Placement uses the authored footprint;
## prices, names, rarity and decor remain owned by the Lua item catalogue.
static func contains(id: Variant) -> bool:
	return ItemKinds.storage_of(id) == ItemKinds.FURNITURE and HomeData.furniture().has(str(id))

static func record(id: Variant) -> Dictionary:
	if not contains(id):
		return {}
	var result := ItemKinds.def(id).duplicate(true)
	result["visual"] = HomeData.furniture()[str(id)].duplicate(true)
	return result

static func mismatches() -> Array:
	var errors: Array = []
	for id in ItemKinds.all_ids("furniture"):
		var content := ItemKinds.def(id)
		var art: Dictionary = HomeData.furniture().get(str(id), {})
		if art.is_empty() or HomeData.rot_dims(LuaData.arr(content.get("footprint", [0, 0])), 0) != HomeData.rot_dims(art.get("footprint", [0, 0]), 0) or str(content.get("placement", "")) != str(art.get("layer", "")):
			errors.append(str(id))
	return errors
