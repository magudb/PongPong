class_name ActorLevel
extends RefCounted
## The level of an ACTOR (player, Npc2D, animals - anything that is a CharacterBody2D inside area.objects), kept in the actor's own
## metadata so nothing in P05 / P06 / P14 has to know about levels (package V3-levels).
##
##   ActorLevel.set_level(actor, level)   z_index = rank; the shadow of the actor's visual (`actor.visual.shadow`, public on IsoChibiSprite2D)
##                                        z_index = rank - 2 (absolute: the chibi shadow is z -5 and would sit under every floor);
##                                        collision_mask = (mask & 0x7F) | (1 << (bit - 1)): the low layers stay (world, npc, resource nodes),
##                                        ground_block and every older level bit go, the level's own bit comes in
##   ActorLevel.restore(actor)            the inverse: z, mask and shadow go back to what they were BEFORE the first level touched the actor,
##                                        the lock and the level are forgotten (the LevelTracker calls it when the actor leaves its area)
##   ActorLevel.lock(actor, level_id)     the LevelTracker skips the actor until unlock(): a ladder tween owns it
##   ActorLevel.unlock(actor)
##   ActorLevel.level_id(actor)           the level the actor was last put on (&"" = none)
##   ActorLevel.is_locked(actor)
## The mask keeps layer 1 (world): the Bounds ring of the area stays solid. Level colliders never use that layer (LevelRegistry / Railing).

const META_LEVEL := &"v3_level"
const META_LOCK := &"v3_level_lock"
## What the actor looked like before the first level touched it: {z, mask, shadow_z, shadow_rel} (each key only once it was read).
## set_level / set_transit write it on the FIRST change, restore() reads it back and removes it, so the next area starts from the true baseline.
const META_ORIGIN := &"v3_origin"
const KEEP_MASK := 0x7F
const SHADOW_Z_OFFSET := -2


## Puts an actor on a level (z, shadow, collision mask). Returns false for a null level or a non-2D actor.
static func set_level(actor: Node, level: Level) -> bool:
	if level == null or not (actor is Node2D):
		return false
	var n2d: Node2D = actor as Node2D
	var sh: Sprite2D = shadow_of(actor)
	_remember(actor, sh)
	n2d.z_index = level.rank
	if actor is CollisionObject2D:
		var co: CollisionObject2D = actor as CollisionObject2D
		co.collision_mask = (co.collision_mask & KEEP_MASK) | level.mask_bit()
	if sh != null:
		sh.z_as_relative = false
		sh.z_index = level.rank + SHADOW_Z_OFFSET
	actor.set_meta(META_LEVEL, level.id)
	return true


## A level change in motion (a ladder climb): drawn at the HIGHER rank of the two levels, collides with no level (the tween ignores them).
static func set_transit(actor: Node, from_level: Level, to_level: Level) -> void:
	if from_level == null or to_level == null or not (actor is Node2D):
		return
	var rank: int = maxi(from_level.rank, to_level.rank)
	var sh: Sprite2D = shadow_of(actor)
	_remember(actor, sh)
	(actor as Node2D).z_index = rank
	if actor is CollisionObject2D:
		var co: CollisionObject2D = actor as CollisionObject2D
		co.collision_mask = co.collision_mask & KEEP_MASK
	if sh != null:
		sh.z_as_relative = false
		sh.z_index = rank + SHADOW_Z_OFFSET


## Puts back what set_level / set_transit changed: z_index, the bits of the collision mask above KEEP_MASK (ground_block and the walking bits
## the level system removed, minus every level bit), the shadow's z_index and z_as_relative; forgets the level and the lock. The low layers
## (world, npc, resource nodes) are NOT touched: whatever the actor's own code did to them meanwhile stays. An actor no level ever touched is
## left as it is (only a stray lock / level id goes). Idempotent.
static func restore(actor: Node) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	if actor.has_meta(META_ORIGIN):
		var o: Dictionary = LuaData.dict(actor.get_meta(META_ORIGIN))
		if actor is Node2D and o.has("z"):
			(actor as Node2D).z_index = int(o["z"])
		if actor is CollisionObject2D and o.has("mask"):
			var co: CollisionObject2D = actor as CollisionObject2D
			co.collision_mask = (co.collision_mask & KEEP_MASK) | (int(o["mask"]) & ~KEEP_MASK)
		if o.has("shadow_z"):
			var sh: Sprite2D = shadow_of(actor)
			if sh != null:
				sh.z_as_relative = bool(o.get("shadow_rel", false))
				sh.z_index = int(o["shadow_z"])
		actor.remove_meta(META_ORIGIN)
	unlock(actor)
	clear(actor)


## Has a level changed this actor (so that restore() has something to put back)?
static func has_origin(actor: Node) -> bool:
	return actor != null and actor.has_meta(META_ORIGIN)


## Takes the snapshot restore() reads: each field once, the first time a level is about to change it.
static func _remember(actor: Node, sh: Sprite2D) -> void:
	var o: Dictionary = LuaData.dict(actor.get_meta(META_ORIGIN)) if actor.has_meta(META_ORIGIN) else {}
	if actor is Node2D and not o.has("z"):
		o["z"] = (actor as Node2D).z_index
	if actor is CollisionObject2D and not o.has("mask"):
		o["mask"] = (actor as CollisionObject2D).collision_mask
	if sh != null and not o.has("shadow_z"):
		o["shadow_z"] = sh.z_index
		o["shadow_rel"] = sh.z_as_relative
	actor.set_meta(META_ORIGIN, o)


## The id of the level the actor stands on (&"" when it has none yet).
static func level_id(actor: Node) -> StringName:
	if actor != null and actor.has_meta(META_LEVEL):
		var v: Variant = actor.get_meta(META_LEVEL)
		return v if v is StringName else StringName(str(v))
	return &""


## Forgets the level so the next tracker tick applies one again (also used when an actor is re-entered into an area).
static func clear(actor: Node) -> void:
	if actor != null and actor.has_meta(META_LEVEL):
		actor.remove_meta(META_LEVEL)


## The tracker skips a locked actor; `level_id` is what the lock is for (the level the actor is meant to stay on).
static func lock(actor: Node, locked_level_id: StringName) -> void:
	actor.set_meta(META_LOCK, locked_level_id)


static func unlock(actor: Node) -> void:
	if actor != null and actor.has_meta(META_LOCK):
		actor.remove_meta(META_LOCK)


static func is_locked(actor: Node) -> bool:
	return actor != null and actor.has_meta(META_LOCK)


static func locked_to(actor: Node) -> StringName:
	if actor != null and actor.has_meta(META_LOCK):
		return StringName(str(actor.get_meta(META_LOCK)))
	return &""


## Does the actor currently carry exactly the z, shadow z and level bit of `level`?
static func is_applied(actor: Node, level: Level) -> bool:
	if level == null or not (actor is Node2D) or level_id(actor) != level.id:
		return false
	if (actor as Node2D).z_index != level.rank:
		return false
	if actor is CollisionObject2D and ((actor as CollisionObject2D).collision_mask & level.mask_bit()) == 0:
		return false
	return true


## The Sprite2D of the actor's visual that draws its shadow (IsoChibiSprite2D.shadow), or null.
static func shadow_of(actor: Node) -> Sprite2D:
	var vis: Variant = actor.get("visual")
	if vis is Object and (vis as Object).get("shadow") is Sprite2D:
		return (vis as Object).get("shadow") as Sprite2D
	for c in actor.get_children():
		if c is IsoChibiSprite2D and (c as IsoChibiSprite2D).shadow != null:
			return (c as IsoChibiSprite2D).shadow
	return null
