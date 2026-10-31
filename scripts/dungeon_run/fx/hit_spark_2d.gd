class_name HitSpark2D
extends RefCounted
static func play(parent: Node, at: Vector2, rarity: Variant = "normal") -> Node2D:
	return DungeonSpark2D.play(parent,at,Color(Rarity.ui(rarity).ring))

static func play_owned(parent: Node, at: Vector2, rarity: Variant, current: Callable) -> Node2D:
	if not current.call(): return null
	return DungeonSpark2D.play_owned(parent,at,Color(Rarity.ui(rarity).ring),current)
