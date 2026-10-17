class_name HealSparkle2D
extends RefCounted
static func play(parent: Node, at: Vector2) -> Node2D:
	return DungeonSpark2D.play(parent,at,Color("f2c3cf"))
