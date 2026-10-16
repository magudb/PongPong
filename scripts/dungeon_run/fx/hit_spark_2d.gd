class_name HitSpark2D
extends RefCounted
static func play(parent: Node, at: Vector2, rarity: Variant = "normal") -> Node2D:
	return DungeonSpark2D.play(parent,at,Color(Rarity.ui(rarity).ring))
