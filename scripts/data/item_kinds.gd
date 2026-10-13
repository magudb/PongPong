class_name ItemKinds
extends RefCounted
## Where an item lives. The backpack (24 slots) holds ordinary items; furniture and clothing go to their own stores so a
## collection of 200 pieces never clogs it. EconomyManager.add_item / remove_item / has_item / count_item route through
## storage_of(); every caller (Lua api.add_item, quest rewards, shops, loot) is unchanged.

const BACKPACK := &"backpack"
const FURNITURE := &"furniture"
const CLOTHING := &"clothing"


static func def(item_id: Variant) -> Dictionary:
	var lr := Svc.node("LuaRuntime")
	return lr.get_item_def(str(item_id)) if lr != null else {}


## furniture -> the furniture store, clothing -> the wardrobe store, everything else -> the backpack
static func storage_of(item_id: Variant) -> StringName:
	match str(def(item_id).get("category", "")):
		"furniture":
			return FURNITURE
		"clothing":
			return CLOTHING
	return BACKPACK


static func rarity_of(item_id: Variant) -> StringName:
	return Rarity.normalize(def(item_id).get("rarity", "normal"))


## unique / legendary items: a second copy is refused (add_item answers false, no warning)
static func is_one_of_a_kind(item_id: Variant) -> bool:
	return Rarity.is_one_of_a_kind(rarity_of(item_id))


## every copy the player owns anywhere (backpack, home chest, furniture stock + placed, wardrobe worn included)
static func owned_total(item_id: Variant) -> int:
	var eco := Svc.node("EconomyManager")
	return int(eco.count_item(StringName(str(item_id)))) if eco != null and eco.has_method("count_item") else 0


## ids of every defined item, optionally of one category
static func all_ids(category: String = "") -> Array:
	var lr := Svc.node("LuaRuntime")
	var out: Array = []
	if lr == null:
		return out
	for id in lr.get_all_item_ids():
		if category == "" or str(lr.get_item_def(id).get("category", "")) == category:
			out.append(str(id))
	return out
