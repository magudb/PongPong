class_name GhostFamilyQuests
extends Node
## Errand state belongs to QuestRuntime.meta, including the chosen owner and parcel.
const LOST := &"ghostfam_hittegods"
var _busy := false
static func attach(manager: Node) -> Node:
	if manager.has_node("FamilyQuests"):return manager.get_node("FamilyQuests")
	var node := GhostFamilyQuests.new()
	node.name = "FamilyQuests"
	manager.add_child(node)
	return node
func _ready() -> void:
	EventBus.quest_accepted.connect(_accepted)
	EventBus.game_event.connect(_event)
	QuestManager.register_offer_gate(LOST,Callable(get_script(),&"can_offer"))
static func can_offer() -> bool:
	return not eligible_owners().is_empty()
static func eligible_owners() -> Array:
	# can_befriend includes the shared NpcDirector.is_absent / hero-twin rule.
	return LuaData.arr(Svc.lua_config("ghostfam_quests.lost",[])).filter(func(row):return SocialManager.can_befriend(str(row.owner)))
func _accepted(_player_id: StringName, _id: StringName) -> void:
	pass # Public notification only; the intentional producer forwards its ticket.
func accepted_owned(runtime: QuestManager.QuestRuntime, owner: Dictionary) -> void:
	if not QuestManager._owner_current(owner) or not _runtime_current(owner.interaction, runtime): return
	var origin: Dictionary = owner.interaction
	PlayerRegistry.for_player(owner.id, func():
		var options := eligible_owners()
		if options.is_empty() or not QuestManager._owner_current(owner) or not _runtime_current(origin, runtime): return
		var index := mini(options.size()-1,floori(SocialManager.roll(["lost_property",SocialManager.week()])*options.size()))
		var chosen := LuaData.dict(options[index])
		if not QuestManager._owner_current(owner) or not _runtime_current(origin, runtime): return
		runtime.meta["lost_owner"] = str(chosen.owner)
		runtime.meta["lost_item"] = str(chosen.item)
		runtime.meta["parcel_given"] = false
		runtime.meta["objective_keys"] = {"return":str(chosen.objective_key)}
		runtime.meta["friendship_rewards"] = {str(chosen.owner):1}
		collect_parcel_owned(origin, runtime))
func _runtime_current(origin: Dictionary, runtime: Variant) -> bool:
	if not EventBus.interaction_current(origin) or runtime == null: return false
	return PlayerRegistry.for_player(origin.recipient.player_id, func(): return QuestManager.active_quests.get(LOST) == runtime)
func collect_parcel() -> bool:
	return collect_parcel_owned(EventBus.interaction_origin())
func collect_parcel_owned(origin: Dictionary, expected: Variant = null) -> bool:
	if _busy or not EventBus.interaction_current(origin): return false
	return PlayerRegistry.for_player(origin.recipient.player_id, func():
		var runtime: Variant = QuestManager.active_quests.get(LOST)
		if runtime == null or (expected != null and runtime != expected) or not _runtime_current(origin, runtime): return false
		if bool(runtime.meta.get("parcel_given",false)): return true
		var item := StringName(str(runtime.meta.get("lost_item","")))
		if item == &"": return false
		var fits := EconomyManager.can_add_item(item)
		if not _runtime_current(origin, runtime): return false
		if not fits:
			EventBus.whisper_requested.emit(tr("GF_QUEST_PARCEL_WAIT"))
			return false
		_busy = true
		EconomyManager.defer_notifications(func() -> void:
			if not _runtime_current(origin, runtime): return
			runtime.meta["parcel_given"] = true
			if not EconomyManager.add_item(item): runtime.meta["parcel_given"] = false)
		_busy = false
		# The original committed parcel is earned even when its publication
		# replaces the profile. Do not read or modify the winner's runtime.
		return bool(runtime.meta.parcel_given))
func _event(id: StringName,payload: Dictionary) -> void:
	if id!=&"gift_given" or _busy or not QuestManager.is_active(LOST):return
	var runtime: QuestManager.QuestRuntime = QuestManager.active_quests[LOST]
	if not bool(runtime.meta.get("parcel_given",false)) or str(payload.get("npc",""))!=str(runtime.meta.get("lost_owner","")) or str(payload.get("item",""))!=str(runtime.meta.get("lost_item","")):return
	_busy = true
	EconomyManager.defer_notifications(func() -> void:
		QuestManager.complete_manual(LOST,&"return")
	)
	_busy = false
