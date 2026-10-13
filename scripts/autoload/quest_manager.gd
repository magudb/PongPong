extends Node
## Quest state machine. Quest *definitions* live in Lua; this tracks runtime progress.

enum QuestState { LOCKED, AVAILABLE, ACTIVE, COMPLETED, FAILED }

const QUEST_LUA_DIR := "res://lua/quests"

var active_quests: Dictionary = {}   # quest_id -> QuestRuntime
var completed_quests: Array[StringName] = []
var failed_quests: Array[StringName] = []
var offered_quests: Array[StringName] = []
var quest_flags: Dictionary = {}


class QuestRuntime:
	var id: StringName
	var state: int
	var objectives: Dictionary = {}  # objective_id -> {current, target, done}
	var started_day: int = 0
	var meta: Dictionary = {}

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"state": state,
			"objectives": objectives.duplicate(true),
			"started_day": started_day,
			"meta": meta.duplicate(),
		}

	static func from_dict(d: Dictionary) -> QuestRuntime:
		var q := QuestRuntime.new()
		q.id = d.get("id", &"")
		q.state = d.get("state", QuestState.ACTIVE)
		q.objectives = d.get("objectives", {}).duplicate(true)
		q.started_day = d.get("started_day", 0)
		q.meta = d.get("meta", {}).duplicate()
		return q


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.lua_event.connect(_on_lua_event)
	EventBus.item_purchased.connect(_on_item_purchased)
	EventBus.crop_harvested.connect(_on_crop_harvested)
	EventBus.resource_node_depleted.connect(_on_resource_depleted)
	EventBus.day_started.connect(_on_day_started)


func register_quest_from_lua(quest_data: Dictionary) -> void:
	var quest_id: StringName = quest_data.get("id", &"")
	if quest_id == &"":
		push_error("Lua quest mangler id")
		return
	# Lua defines availability; we only store the definition cache
	quest_flags["def_%s" % quest_id] = quest_data


func offer_quest(quest_id: StringName) -> void:
	if quest_id in completed_quests or quest_id in active_quests or quest_id in offered_quests:
		return
	offered_quests.append(quest_id)
	EventBus.quest_offered.emit(quest_id)


func accept_quest(quest_id: StringName) -> bool:
	if quest_id in active_quests or quest_id in completed_quests:
		return false

	var def := get_quest_def(quest_id)
	if def.is_empty():
		push_warning("Ukendt quest: %s" % quest_id)
		return false

	var rt := QuestRuntime.new()
	rt.id = quest_id
	rt.state = QuestState.ACTIVE
	rt.started_day = GameManager.day
	rt.meta = def.get("meta", {}).duplicate()

	for obj in def.get("objectives", []):
		rt.objectives[obj["id"]] = {
			"current": 0,
			"target": obj.get("target", 1),
			"done": false,
		}

	active_quests[quest_id] = rt
	offered_quests.erase(quest_id)
	EventBus.quest_accepted.emit(quest_id)
	EventBus.notification_posted.emit(
		tr("NOTIF_QUEST_ACCEPTED_TITLE"),
		tr("QUEST_%s_TITLE" % quest_id.to_upper()),
		"quest"
	)
	_lua_notify("quest_accepted", quest_id)
	return true


func update_objective(quest_id: StringName, objective_id: StringName, amount: int = 1) -> void:
	if quest_id not in active_quests:
		return
	var rt: QuestRuntime = active_quests[quest_id]
	if objective_id not in rt.objectives:
		return
	var obj: Dictionary = rt.objectives[objective_id]
	if obj["done"]:
		return
	obj["current"] = mini(obj["current"] + amount, obj["target"])
	if obj["current"] >= obj["target"]:
		obj["done"] = true
	EventBus.quest_objective_updated.emit(quest_id, objective_id, obj["current"], obj["target"])
	_check_completion(quest_id)


func complete_quest(quest_id: StringName) -> void:
	if quest_id not in active_quests:
		return
	var def := get_quest_def(quest_id)
	var rewards: Dictionary = def.get("rewards", {})

	if rewards.has("gold"):
		EconomyManager.add_gold(int(rewards["gold"]))
	for item_id in rewards.get("items", {}):
		EconomyManager.add_item(StringName(item_id), int(rewards["items"][item_id]))

	active_quests.erase(quest_id)
	completed_quests.append(quest_id)
	EventBus.quest_completed.emit(quest_id)
	EventBus.notification_posted.emit(
		tr("NOTIF_QUEST_COMPLETED_TITLE"),
		tr("QUEST_%s_TITLE" % quest_id.to_upper()),
		"quest_done"
	)
	_lua_notify("quest_completed", quest_id)


func fail_quest(quest_id: StringName) -> void:
	if quest_id not in active_quests:
		return
	active_quests.erase(quest_id)
	failed_quests.append(quest_id)
	EventBus.quest_failed.emit(quest_id)
	_lua_notify("quest_failed", quest_id)


func get_quest_def(quest_id: StringName) -> Dictionary:
	return quest_flags.get("def_%s" % quest_id, {})


func get_active_quests() -> Array:
	return active_quests.values()


func is_completed(quest_id: StringName) -> bool:
	return quest_id in completed_quests


func is_active(quest_id: StringName) -> bool:
	return quest_id in active_quests


func get_quest_progress(quest_id: StringName) -> Dictionary:
	if quest_id not in active_quests:
		return {}
	return (active_quests[quest_id] as QuestRuntime).to_dict()


func _check_completion(quest_id: StringName) -> void:
	var rt: QuestRuntime = active_quests[quest_id]
	for obj_id in rt.objectives:
		if not rt.objectives[obj_id]["done"]:
			return
	complete_quest(quest_id)


func _lua_notify(event: String, quest_id: StringName) -> void:
	LuaRuntime.call_quest_event(str(quest_id), event, {"quest_id": str(quest_id)})


func _on_lua_event(event_name: StringName, payload: Dictionary) -> void:
	match event_name:
		&"quest_offer":
			offer_quest(StringName(payload.get("quest_id", "")))
		&"quest_accept":
			accept_quest(StringName(payload.get("quest_id", "")))
		&"quest_update":
			update_objective(
				StringName(payload.get("quest_id", "")),
				StringName(payload.get("objective_id", "")),
				int(payload.get("amount", 1))
			)
		&"quest_complete":
			complete_quest(StringName(payload.get("quest_id", "")))
		&"quest_fail":
			fail_quest(StringName(payload.get("quest_id", "")))


func _on_item_purchased(_item_id: StringName, _amount: int, _cost: int) -> void:
	# Hook for shopping quests
	pass


func _on_crop_harvested(_plot: StringName, crop_id: StringName, amount: int) -> void:
	for quest_id in active_quests:
		update_objective(quest_id, &"harvest_%s" % crop_id, amount)
		update_objective(quest_id, &"harvest_any", amount)


func _on_resource_depleted(_node_id: StringName, loot: Array) -> void:
	for quest_id in active_quests:
		for entry in loot:
			var item_id: StringName = entry.get("id", &"")
			var amount: int = entry.get("amount", 1)
			update_objective(quest_id, &"collect_%s" % item_id, amount)


func _on_day_started(_day: int, _season: StringName) -> void:
	for quest_id in active_quests:
		_lua_notify("day_started", quest_id)


func to_dict() -> Dictionary:
	var active := {}
	for qid in active_quests:
		active[qid] = (active_quests[qid] as QuestRuntime).to_dict()
	return {
		"active": active,
		"completed": completed_quests.duplicate(),
		"failed": failed_quests.duplicate(),
		"offered": offered_quests.duplicate(),
		"flags": quest_flags.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	active_quests.clear()
	var active: Dictionary = data.get("active", {})
	for qid in active:
		active_quests[qid] = QuestRuntime.from_dict(active[qid])
	completed_quests.assign(data.get("completed", []))
	failed_quests.assign(data.get("failed", []))
	offered_quests.assign(data.get("offered", []))
	quest_flags = data.get("flags", {}).duplicate()
