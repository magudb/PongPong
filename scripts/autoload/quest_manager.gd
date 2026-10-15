extends Node
## Quest state machine. Quest *definitions* live in Lua; this tracks runtime progress.

enum QuestState { LOCKED, AVAILABLE, ACTIVE, COMPLETED, FAILED }

const QUEST_LUA_DIR := "res://lua/quests"

var active_quests: Dictionary = {}   # quest_id -> QuestRuntime
var completed_quests: Array[StringName] = []
var failed_quests: Array[StringName] = []
var offered_quests: Array[StringName] = []
var quest_flags: Dictionary = {}
## Lua quest definitions by id (registered at LuaRuntime load, never saved, survive reset()/from_dict()).
var quest_defs: Dictionary = {}
## Absolute completion day per quest; completed_quests remains the history used by dialogue and map conditions.
var completed_days: Dictionary = {}
## quest id -> {item id: amount} still owed. Successful deliveries are removed before another claim can run.
var pending_rewards: Dictionary = {}

var _claiming_rewards: bool = false
var _reward_claim_queued: bool = false


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
	EventBus.item_gained.connect(_on_item_gained)
	EventBus.day_started.connect(_on_day_started)
	EventBus.new_game_started.connect(reset)
	EventBus.player_inventory_changed.connect(_on_inventory_changed)
	EventBus.load_completed.connect(_on_load_completed)


## A new run forgets progress and rewards, but keeps the definitions registered by LuaRuntime at boot.
func reset() -> void:
	active_quests.clear()
	completed_quests.clear()
	failed_quests.clear()
	offered_quests.clear()
	completed_days.clear()
	pending_rewards.clear()
	_reward_claim_queued = false
	quest_flags.clear()


func register_quest_from_lua(quest_data: Dictionary) -> void:
	var quest_id: StringName = quest_data.get("id", &"")
	if quest_id == &"":
		push_error("Lua quest is missing an id")
		return
	# Lua defines availability; we only store the definition cache
	quest_defs[quest_id] = quest_data


func offer_quest(quest_id: StringName) -> void:
	if get_quest_def(quest_id).is_empty() or not _can_start(quest_id) or quest_id in offered_quests:
		return
	offered_quests.append(quest_id)
	EventBus.quest_offered.emit(quest_id)


func accept_quest(quest_id: StringName) -> bool:
	if not _can_start(quest_id):
		return false

	var def := get_quest_def(quest_id)
	if def.is_empty():
		push_warning("Unknown quest: %s" % quest_id)
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


func _can_start(quest_id: StringName) -> bool:
	if quest_id in active_quests:
		return false
	if quest_id in completed_quests:
		var meta: Dictionary = get_quest_def(quest_id).get("meta", {})
		if not bool(meta.get("repeatable", false)):
			return false
		var cooldown := maxi(int(meta.get("cooldown_days", 0)), 0)
		if GameManager.total_day() - int(completed_days.get(quest_id, GameManager.total_day())) < cooldown:
			return false
	return _lua_available(quest_id)


## The Lua is_available(context) hook of the quest (a quest without one is always available). An unknown quest id is
## never available; the runtime refuses it too (accept_quest checks the def as well).
func _lua_available(quest_id: StringName) -> bool:
	var lr := get_node_or_null("/root/LuaRuntime")
	if lr == null or not lr.has_method("is_quest_available"):
		return true
	return bool(lr.call("is_quest_available", str(quest_id), _quest_context()))


## The context table handed to is_available / on_offer: day, gold and home_tier; world flags are still reachable as
## bare identifiers inside the Lua function (slotsdroemmen reads context.home_tier).
func _quest_context() -> Dictionary:
	return {
		"day": GameManager.total_day(),
		"gold": EconomyManager.gold,
		"home_tier": GameManager.flag_int(GameManager.FLAG_HOME_TIER, 1),
	}


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


func can_complete_manual(quest_id: StringName, objective_id: StringName) -> bool:
	if not active_quests.has(quest_id):
		return false
	var rt: QuestRuntime = active_quests[quest_id]
	return rt.objectives.has(objective_id) and not bool(rt.objectives[objective_id]["done"])


## Manual map interactions commit all resource costs before publishing quest or inventory signals.
func complete_manual(quest_id: StringName, objective_id: StringName, needs: Dictionary = {}, consume: bool = false) -> bool:
	if not can_complete_manual(quest_id, objective_id):
		return false
	var rt: QuestRuntime = active_quests[quest_id]
	var remaining := int(rt.objectives[objective_id]["target"]) - int(rt.objectives[objective_id]["current"])
	var commit := func() -> void: update_objective(quest_id, objective_id, remaining)
	if consume:
		return EconomyManager.consume_backpack_items(needs, commit)
	if not EconomyManager.has_items(needs):
		return false
	commit.call()
	return true


func complete_quest(quest_id: StringName) -> void:
	if quest_id not in active_quests:
		return
	var def := get_quest_def(quest_id)
	var rewards: Dictionary = def.get("rewards", {})

	# Commit completion before grants: inventory and gold listeners may synchronously call back into the quest manager.
	active_quests.erase(quest_id)
	if quest_id not in completed_quests:
		completed_quests.append(quest_id)
	completed_days[quest_id] = GameManager.total_day()
	var owed: Dictionary = pending_rewards.get(quest_id, {})
	for item_id in rewards.get("items", {}):
		var amount := int(rewards["items"][item_id])
		if amount > 0:
			owed[str(item_id)] = int(owed.get(str(item_id), 0)) + amount
	if not owed.is_empty():
		pending_rewards[quest_id] = owed
	if rewards.has("gold"):
		EconomyManager.add_gold(int(rewards["gold"]))
	claim_rewards()
	EventBus.quest_completed.emit(quest_id)
	EventBus.notification_posted.emit(
		tr("NOTIF_QUEST_COMPLETED_TITLE"),
		tr("QUEST_%s_TITLE" % quest_id.to_upper()),
		"quest_done"
	)
	_lua_notify("quest_completed", quest_id)


## Delivers what fits, retaining the rest in the save. Called again after inventory changes and successful loads.
## Returns true when nothing remains owed. The guard prevents item-gained listeners from claiming a grant twice.
func claim_rewards() -> bool:
	if _claiming_rewards:
		return pending_rewards.is_empty()
	_claiming_rewards = true
	for quest_id in pending_rewards.keys():
		var owed: Dictionary = pending_rewards[quest_id]
		for item_id in owed.keys():
			var amount := int(owed[item_id])
			if not EconomyManager.can_add_item(StringName(item_id), amount):
				continue
			# item_gained listeners may save immediately: at that point the grant is owned and must no longer be owed.
			owed.erase(item_id)
			if not EconomyManager.add_item(StringName(item_id), amount):
				owed[item_id] = amount
		if owed.is_empty():
			pending_rewards.erase(quest_id)
	_claiming_rewards = false
	return pending_rewards.is_empty()


func _on_inventory_changed(_inventory: Dictionary) -> void:
	_queue_reward_claim()


func _on_load_completed(_slot: int) -> void:
	_queue_reward_claim()


func _queue_reward_claim() -> void:
	if pending_rewards.is_empty() or _claiming_rewards or _reward_claim_queued:
		return
	_reward_claim_queued = true
	_run_reward_claim.call_deferred()


func _run_reward_claim() -> void:
	if not _reward_claim_queued:
		return
	_reward_claim_queued = false
	claim_rewards()


func fail_quest(quest_id: StringName) -> void:
	if quest_id not in active_quests:
		return
	active_quests.erase(quest_id)
	failed_quests.append(quest_id)
	EventBus.quest_failed.emit(quest_id)
	_lua_notify("quest_failed", quest_id)


func get_quest_def(quest_id: StringName) -> Dictionary:
	return quest_defs.get(quest_id, {})


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
	for quest_id in active_quests.keys():
		update_objective(quest_id, &"harvest_%s" % crop_id, amount)
		update_objective(quest_id, &"harvest_any", amount)


func _on_resource_depleted(_node_id: StringName, loot: Array) -> void:
	for quest_id in active_quests.keys():
		for entry in loot:
			var item_id: StringName = entry.get("id", &"")
			var amount: int = entry.get("amount", 1)
			update_objective(quest_id, &"collect_%s" % item_id, amount)


## `collect_<item>` is the "the player received it" objective: harvest, buy and gift all route through
## EconomyManager.add_item -> item_gained (a silent add - starter kit, load - does not count).
## NOTE for the node-loot wave: emit resource_node_depleted only for loot that did NOT go through add_item,
## or collect_<item> advances twice.
func _on_item_gained(item_id: StringName, amount: int) -> void:
	for quest_id in active_quests.keys():
		update_objective(quest_id, &"collect_%s" % item_id, amount)


func _on_day_started(_day: int, _season: StringName) -> void:
	for quest_id in active_quests.keys():
		if quest_id in active_quests:
			_lua_notify("day_started", quest_id)


func to_dict() -> Dictionary:
	var active := {}
	for qid in active_quests:
		active[qid] = (active_quests[qid] as QuestRuntime).to_dict()
	return {
		"v": 2,
		"active": active,
		"completed": completed_quests.duplicate(),
		"failed": failed_quests.duplicate(),
		"offered": offered_quests.duplicate(),
		"flags": quest_flags.duplicate(),
		"completed_days": completed_days.duplicate(),
		"pending_rewards": pending_rewards.duplicate(true),
	}


## Validate the complete runtime shape before a slot is selected, rotated or applied.
func validate_dict(data: Dictionary) -> bool:
	var active: Variant = data.get("active", {})
	if not (active is Dictionary) or not (data.get("flags", {}) is Dictionary):
		return false
	for list_key in ["completed", "failed", "offered"]:
		var ids: Variant = data.get(list_key, [])
		if not (ids is Array):
			return false
		for id in ids:
			if not _valid_id(id):
				return false
	for quest_id in active:
		var record: Variant = active[quest_id]
		if not _valid_id(quest_id) or not (record is Dictionary):
			return false
		if not _valid_id(record.get("id", "")) or str(record["id"]) != str(quest_id):
			return false
		var state: Variant = record.get("state", QuestState.ACTIVE)
		if not _valid_count(state) or int(state) > QuestState.FAILED or not _valid_count(record.get("started_day", 0)):
			return false
		if not (record.get("meta", {}) is Dictionary) or not (record.get("objectives", {}) is Dictionary):
			return false
		for objective_id in record.get("objectives", {}):
			var objective: Variant = record["objectives"][objective_id]
			if not _valid_id(objective_id) or not (objective is Dictionary):
				return false
			if not _valid_count(objective.get("current")) or not _valid_count(objective.get("target")):
				return false
			if int(objective["target"]) <= 0 or int(objective["current"]) > int(objective["target"]) or not (objective.get("done") is bool):
				return false
	var days: Variant = data.get("completed_days", {})
	var pending: Variant = data.get("pending_rewards", {})
	if not (days is Dictionary) or not (pending is Dictionary):
		return false
	for quest_id in days:
		if not _valid_id(quest_id) or not _valid_count(days[quest_id]):
			return false
	for quest_id in pending:
		if not _valid_id(quest_id) or not (pending[quest_id] is Dictionary):
			return false
		for item_id in pending[quest_id]:
			var amount: Variant = pending[quest_id][item_id]
			if not _valid_id(item_id) or not _valid_count(amount) or int(amount) <= 0:
				return false
	return true


static func _valid_id(value: Variant) -> bool:
	return (value is String or value is StringName) and str(value) != ""


static func _valid_count(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return is_finite(number) and number >= 0.0 and number <= 9007199254740991.0 and number == floorf(number)


func from_dict(data: Dictionary) -> bool:
	if not validate_dict(data):
		return false
	var restored: Dictionary = {}
	var active: Dictionary = data.get("active", {})
	for qid in active:
		restored[qid] = QuestRuntime.from_dict(active[qid])
	active_quests = restored
	completed_quests.assign(data.get("completed", []))
	failed_quests.assign(data.get("failed", []))
	offered_quests.assign(data.get("offered", []))
	quest_flags.clear()
	for key in data.get("flags", {}):
		if not str(key).begins_with("def_"):   # v1 saves carried quest defs as flags; defs are never loaded
			quest_flags[key] = data["flags"][key]
	completed_days.clear()
	var saved_days: Dictionary = data.get("completed_days", {})
	for quest_id in completed_quests:
		# Old saves have no completion dates: start their cooldown at the loaded date rather than inventing past progress.
		completed_days[quest_id] = int(saved_days.get(quest_id, GameManager.total_day()))
	pending_rewards = (data.get("pending_rewards", {}) as Dictionary).duplicate(true)
	_reward_claim_queued = false
	return true
