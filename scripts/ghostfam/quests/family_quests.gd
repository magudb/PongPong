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
func _accepted(_player_id: StringName, id: StringName) -> void:
	if id!=LOST:return
	var options := eligible_owners()
	if options.is_empty():return
	var index := mini(options.size()-1,floori(SocialManager.roll(["lost_property",SocialManager.week()])*options.size()))
	var chosen := LuaData.dict(options[index])
	var runtime: QuestManager.QuestRuntime = QuestManager.active_quests[LOST]
	runtime.meta["lost_owner"] = str(chosen.owner)
	runtime.meta["lost_item"] = str(chosen.item)
	runtime.meta["parcel_given"] = false
	runtime.meta["objective_keys"] = {"return":str(chosen.objective_key)}
	runtime.meta["friendship_rewards"] = {str(chosen.owner):1}
	collect_parcel()
func collect_parcel() -> bool:
	if _busy or not QuestManager.is_active(LOST):return false
	var runtime: QuestManager.QuestRuntime = QuestManager.active_quests[LOST]
	if bool(runtime.meta.get("parcel_given",false)):return true
	var item := StringName(str(runtime.meta.get("lost_item","")))
	if not EconomyManager.can_add_item(item):
		EventBus.whisper_requested.emit(tr("GF_QUEST_PARCEL_WAIT"))
		return false
	_busy = true
	EconomyManager.defer_notifications(func() -> void:
		runtime.meta["parcel_given"] = true
		if not EconomyManager.add_item(item):runtime.meta["parcel_given"] = false
	)
	_busy = false
	return bool(runtime.meta.parcel_given)
func _event(id: StringName,payload: Dictionary) -> void:
	if id!=&"gift_given" or _busy or not QuestManager.is_active(LOST):return
	var runtime: QuestManager.QuestRuntime = QuestManager.active_quests[LOST]
	if not bool(runtime.meta.get("parcel_given",false)) or str(payload.get("npc",""))!=str(runtime.meta.get("lost_owner","")) or str(payload.get("item",""))!=str(runtime.meta.get("lost_item","")):return
	_busy = true
	EconomyManager.defer_notifications(func() -> void:
		QuestManager.complete_manual(LOST,&"return")
	)
	_busy = false
