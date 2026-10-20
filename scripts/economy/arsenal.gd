class_name Arsenal
extends Node
## Weapons stay owned outside the backpack; the equipped copy is never spare stock.
const CAP := 9
var owned: Dictionary = {}
## Weapons of a save that this build cannot hold (content drift: no longer a weapon, or copies above today's cap): {id: count}.
## Saved as they were and owned again by the load that can hold them.
var orphans: Dictionary = {}
func count_total(id: Variant) -> int:
	return int(owned.get(StringName(str(id)),0))
func count_stock(id: Variant) -> int:
	var owner := get_parent()
	var equipped := owner != null and owner.has_method("equipped_item") and str(owner.equipped_item(&"weapon")) == str(id)
	return maxi(0,count_total(id)-(1 if equipped else 0))
func owned_ids() -> Array:
	return owned.keys()
func can_add(id: Variant, amount: int = 1) -> bool:
	var cap := 1 if ItemKinds.is_one_of_a_kind(id) else CAP
	return str(ItemKinds.def(id).get("category","")) == "weapon" and amount > 0 and amount <= cap and count_total(id) <= cap-amount
func add(id: Variant, amount: int = 1) -> bool:
	if not can_add(id,amount): return false
	owned[StringName(str(id))] = count_total(id)+amount
	return true
func remove(id: Variant, amount: int = 1) -> bool:
	if amount <= 0 or count_stock(id) < amount: return false
	var remaining := count_total(id)-amount
	if remaining == 0: owned.erase(StringName(str(id)))
	else: owned[StringName(str(id))] = remaining
	return true
func reset() -> void:
	owned.clear()
	orphans.clear()
## {id: count}, plus "_orphans": {id: count} while there are any (no weapon id starts with an underscore).
func to_dict() -> Dictionary:
	var out := {}
	for id in owned: out[str(id)] = owned[id]
	if not orphans.is_empty(): out["_orphans"] = orphans.duplicate()
	return out
func from_dict(data: Dictionary) -> bool:
	reset()
	var all := {}
	var kept: Variant = data.get("_orphans", {})
	for source in [data, kept if kept is Dictionary else {}]:
		for id in source:
			var n: Variant = source[id]
			if str(id) == "_orphans" or typeof(n) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(n)) or float(n) < 1 or float(n) != floorf(float(n)): continue
			all[str(id)] = int(all.get(str(id), 0)) + int(n)
	for id in all:
		var cap := 1 if ItemKinds.is_one_of_a_kind(id) else CAP
		var fits := mini(int(all[id]), cap) if str(ItemKinds.def(id).get("category","")) == "weapon" else 0
		if fits > 0: owned[StringName(id)] = fits
		if int(all[id]) > fits and not (fits > 0 and ItemKinds.is_one_of_a_kind(id)): orphans[id] = int(all[id]) - fits
	return true
