class_name GhostFamHook
extends RefCounted
## Late-bound family effects; optional targets never change unrelated citizens.
static var glow_path := "res://scripts/ghostfam/glow/npc_glow.gd"
static var seek_path := "res://scripts/ghostfam/seek/hide_seek.gd"
static func attach(npc: Node) -> void:
	if not str(npc.get("npc_id")).begins_with("ghostfam_"):
		return
	Svc.static_call(glow_path, &"attach", [npc])
	if str(npc.get("npc_id")) == "ghostfam_blund":
		Svc.static_call(seek_path, &"attach", [npc])

static func before_talk(npc: Node,player: Node) -> bool:
	if str(npc.get("npc_id"))=="ghostfam_silke":
		var manager := Svc.node("SocialManager")
		var quests := manager.get_node_or_null("FamilyQuests") if manager!=null else null
		if quests!=null:quests.collect_parcel()
	if str(npc.get("npc_id")) != "ghostfam_blund":return true
	var seek := npc.get_node_or_null("HideSeek")
	return bool(seek.before_talk(player)) if seek != null else true

static func dialogue_context(npc_id: String,context: Dictionary) -> Dictionary:
	if npc_id != "ghostfam_blund":return context
	var slot: Dictionary = Svc.static_call(seek_path,&"slot_now",[],{})
	context["ghostfam_seek_again"] = not slot.is_empty() and bool(Svc.static_call(seek_path,&"found_slot",[int(slot.get("number",0))],false))
	return context
