class_name DungeonLootRng
extends RefCounted
static func keyed(stream: String, key: Variant) -> DungeonRng:
	var floors := DungeonFloors.inst()
	if floors != null: return floors.rng_keyed(stream,key)
	var loot := Svc.node("LootService")
	return DungeonRng.new(DungeonRng.hash_key(str(loot.world_seed if loot != null else 0)+"|"+stream,0,DungeonRng.hash_key(str(key),0,0)&0x7fffffff))
