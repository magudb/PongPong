class_name GhostFamHook
extends RefCounted
## M1b data dispatcher. Later glow and counted hide-and-seek remain optional.
static var glow_path := "res://scripts/ghostfam/glow/npc_glow.gd"
static var seek_path := "res://scripts/ghostfam/seek/hide_seek.gd"
static func attach(npc: Node) -> void:
	if not str(npc.get("npc_id")).begins_with("ghostfam_"):
		return
	Svc.static_call(glow_path, &"attach", [npc])
	if str(npc.get("npc_id")) == "ghostfam_blund":
		Svc.static_call(seek_path, &"attach", [npc])
