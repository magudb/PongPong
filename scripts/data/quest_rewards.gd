extends RefCounted
## Resolve static rewards plus the named recipient of a procedural errand.
## Runtime friendship rewards are additive and bounded by the normal heart cap.
static func resolve(definition: Dictionary,meta: Dictionary = {}) -> Dictionary:
	var rewards := LuaData.dict(definition.get("rewards",{})).duplicate(true)
	var friendship := LuaData.int_map(rewards.get("friendship",{}))
	var extra := LuaData.int_map(meta.get("friendship_rewards",{}))
	for npc in extra:
		var amount := clampi(int(extra[npc]),0,10)
		if amount>0:friendship[npc] = mini(10,int(friendship.get(npc,0))+amount)
	if not friendship.is_empty():rewards["friendship"] = friendship
	return rewards
