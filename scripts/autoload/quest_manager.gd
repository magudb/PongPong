extends Node
## QuestManager: quest state machine and the objective-binding runtime (package P13, PLAN 3.12 + the addenda).
##
## Quest DEFINITIONS live in Lua (lua/quests/*.lua, registered by LuaRuntime through register_quest_from_lua) and are never saved;
## this node keeps the RUNTIME: active quests with their objective progress, the completed / failed / offered lists, the repeatable-quest
## cooldowns, the rewards still owed (review fixes: a full backpack keeps them in the save) and the free `quest_flags`.
##
## OBJECTIVE BINDINGS. An objective is a Lua table `{ id, target, on = "<kind>", <filter fields>, description_key, ... }`; the field `on`
## says which game event feeds it, the filter fields narrow the event down (a missing filter matches anything; every filter value may be a
## comma list "a,b"). Progress is `amount` per event (the event's own amount for item / harvest / product events, 1 for the rest; the field
## `amount = n` overrides it).
##   item_gained(item)              EventBus.item_gained            crop_planted(crop?)         EventBus.crop_planted
##   crop_watered                   EventBus.crop_watered           crop_harvested(crop?)       EventBus.crop_harvested
##   zone_entered(zone)             EventBus.zone_entered          (fires on EVERY area change: harmless for target 1)
##   area_changed(area)             EventBus.area_changed (a MAP id: moerkeskoven_f4 - zone ids are shared by several maps)
##   dialogue_started(npc | any_of) EventBus.dialogue_started       any_of = { ... }: each listed NPC counts once (target <= size)
##   animal_adopted(species?) animal_fed(food?) animal_product_collected(product) building_built(type) enemy_defeated(kind) recipe_crafted(recipe)
##   quest_completed(quest? category?)   another quest was completed (category / quest id narrow it down)
##   game_event(event, rarity?, min_level?, match?)   EventBus.game_event(name, payload): `rarity` = comma list against payload.rarity,
##                                  `min_level` = payload.level >= n for ANY event (dungeon: level = floor; furniture: hygge level index),
##                                  `match = { npc = "..", item = "..", id = ".." }` = payload entries that must be equal
##   gift_given(npc? item?) festival_attended heart_event_finished(npc?)   sugar over game_event of the same name (a payload id: match = { id = ".." })
##   state(state = placed_by_rarity | hygge_level_at_least | home_tier_at_least | friend_hearts_at_least, rarity | min_level | npc + hearts)
##                                  a QUERY, not an event: evaluated when the quest is accepted, on load and on furniture_changed,
##                                  hygge_changed, home_upgraded, friend_changed; progress = min(target, answer) and it stays done once reached
##   manual                         finished by a quest_spot marker (complete_manual), a dialogue action (update_objective) or a Lua hook
## Flags: `after_others = true` (a turn-in: counts only when every objective that is not itself a turn-in was done BEFORE the event),
## `have = true` (on = item_gained: progress = how many the player owns, stays done once reached), `needs = { item = n }` (+ `consume = true`: a
## delivery - the items leave the backpack in the same commit as the progress; also read by item_in_use for quest_spot objectives).
## completed_flag names an already-earned saved achievement that also satisfies an event objective on acceptance/load (the whole target; while
## the flag is unset the objective counts its events as usual).
## An objective without `on` is manual, except for the old id convention that review_regressions pins: harvest_<crop> / harvest_any are fed by
## crop_harvested and collect_<item> by item_gained or resource_node_depleted (for direct node loot).
##
## OFFERS (QuestManager.offerable / offerable_for): quests available RIGHT NOW (Lua is_available, not active, not done or cooled down, the zone
## of meta.requires_zone unlocked) per giver. requires_zone gates offers only: accept_quest by an explicit dialogue choice is never blocked by it.
##
## SAVE: to_dict() carries only runtime state (active records incl. objective progress, completed / failed / offered, flags, completion days,
## owed rewards); definitions are re-registered by LuaRuntime at boot and survive reset() and from_dict().

enum QuestState { LOCKED, AVAILABLE, ACTIVE, COMPLETED, FAILED }

const _Svc := preload("res://scripts/data/svc.gd")
const _Data := preload("res://scripts/data/lua_data.gd")
const _Kinds := preload("res://scripts/data/item_kinds.gd")

const QUEST_LUA_DIR := "res://lua/quests"
const FRIEND_CAP := 10
const DEFAULT_TRACKED := 3
## The version of the "quests" section this build writes (SaveManager: a newer "v" makes the slot "newer", not damaged).
const SECTION_VERSION := 2
const QUEST_TAGS: Array[String] = ["FIND", "HØST", "BYG", "SKOV", "LÆR", "VENSKAB"]

## on = <kind> -> the objective fields that must equal the same-named entry of the event. `dialogue_started` also reads any_of, the
## game_event family reads event / rarity / min_level / match (see _game_event_matches).
const FILTERS := {
	"item_gained": ["item"],
	"crop_planted": ["crop"],
	"crop_watered": [],
	"crop_harvested": ["crop"],
	"zone_entered": ["zone"],
	"dialogue_started": ["npc", "dialogue"],
	"animal_adopted": ["species"],
	"animal_fed": ["food"],
	"animal_product_collected": ["product"],
	"building_built": ["type"],
	"enemy_defeated": ["kind"],
	"recipe_crafted": ["recipe"],
	"quest_completed": ["quest", "category"],
	"area_changed": ["area"],
}
## sugar over game_event: on = <event name>, the listed objective fields must equal the payload entries of the same name. The payload `id` (a
## festival, a heart event) cannot be a field here - `id` is the objective's own - so it is named through `match = { id = ".." }`.
const GAME_EVENT_SUGAR := {
	"gift_given": ["npc", "item"],
	"festival_attended": [],
	"heart_event_finished": ["npc"],
}
## fields an `on` cannot do without (the binding lint, validate_definition)
const REQUIRED_FIELDS := {
	"item_gained": ["item"],
	"zone_entered": ["zone"],
	"area_changed": ["area"],
	"game_event": ["event"],
	"recipe_crafted": ["recipe"],
	"building_built": ["type"],
	"enemy_defeated": ["kind"],
	"animal_product_collected": ["product"],
	"state": ["state"],
}
## state queries that exist, with the fields each one needs. `threshold` queries answer 1 when the value reaches the field `min_level` / `hearts`.
const STATE_QUERIES := {
	"buildings_owned": {"fields": ["type"], "threshold": false},
	"animals_owned": {"fields": [], "threshold": false},
	"placed_by_rarity": {"fields": ["rarity"], "threshold": false},
	"hygge_level_at_least": {"fields": ["min_level"], "threshold": true},
	"home_tier_at_least": {"fields": ["min_level"], "threshold": true},
	"friend_hearts_at_least": {"fields": ["npc", "hearts"], "threshold": true},
}

## Lua quest definitions by id (registered at LuaRuntime load, never saved, survive reset()/from_dict()).
var quest_defs: Dictionary = {}
## Per-player quest rows (MP3). active/completed/failed/offered/flags/days/rewards live on PlayerState.quests;
## single-player has one row and this facade is unchanged from the outside. quest_defs stays global.

var _claiming_rewards: bool = false
var _claim_again: bool = false           # a claim was asked for while one ran (a reward completed another quest): run another pass
var _reward_claim_queued: bool = false
var _refresh_queued: bool = false
var _reward_owners: Dictionary = {}
var _refresh_owners: Dictionary = {}

## A queued notification owns a row/body/session incarnation, not whichever
## player happens to be ambient when Godot dispatches the deferred call.
func _owner_ticket(id: StringName) -> Dictionary:
	var row := PlayerRegistry.peek_state(id)
	if row == null: return {}
	var world := PlayerRegistry.world()
	var body := PlayerRegistry.by_id(id)
	if NetAuthority.owns_network_world() and body == null: return {}
	var session: Node = world.get("session") if world != null else null
	return {"id": id, "row": row, "world": weakref(world) if world != null else null, "body": weakref(body) if body != null else null, "session": weakref(session) if session != null else null, "epoch": session.generation if session != null else 0}

func _owner_current(ticket: Dictionary) -> bool:
	if not NetAuthority.can_write() or PlayerRegistry.peek_state(ticket.id) != ticket.row: return false
	var world: Variant = ticket.world.get_ref() if ticket.world != null else null
	if ticket.world != null and (not is_instance_valid(world) or PlayerRegistry.world() != world): return false
	if ticket.world == null and PlayerRegistry.world() != null: return false
	if ticket.body != null:
		var body: Variant = ticket.body.get_ref()
		if not is_instance_valid(body) or PlayerRegistry.by_id(ticket.id) != body or PlayerRegistry.registered_id(body) != ticket.id: return false
	if ticket.session != null:
		var session: Variant = ticket.session.get_ref()
		if not is_instance_valid(session) or world == null or world.get("session") != session or session.generation != ticket.epoch: return false
	return true

func _for_event_owner(id: StringName, work: Callable) -> void:
	if not NetAuthority.can_write() or PlayerRegistry.peek_state(id) == null: return
	if NetAuthority.owns_network_world() and PlayerRegistry.by_id(id) == null: return
	PlayerRegistry.for_player(id, work)

var _dispatch_depth: int = 0
var _giver_index: Dictionary = {}        # meta.giver -> [quest ids, sorted]: built once per set of definitions, not per offerable() call (SYS-04)
var _giver_index_size: int = -1          # quest_defs.size() the index was built for (-1 = stale)
var _missing: Dictionary = {}            # item id -> amount a delivery needs, gathered while one event is dispatched: ONE toast per event
var _accept_counter: int = 0
var _state_queries: Dictionary = {}      # query name -> Callable(objective def) -> int, registered by the owner of the data
var _offer_gates: Dictionary = {} # quest id -> a static eligibility query; retained across runs
var _objective_cache: Dictionary = {}    # quest id -> {"def": the definition it was built from, "map": {objective id: def}}


class QuestRuntime:
	var id: StringName
	var state: int
	var objectives: Dictionary = {}  # objective_id -> {current, target, done[, seen: [npc ids]]}
	var started_day: int = 0
	var order: int = 0               # acceptance order: get_tracked / the journal list the oldest first
	var meta: Dictionary = {}

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"state": state,
			"objectives": objectives.duplicate(true),
			"started_day": started_day,
			"order": order,
			"meta": meta.duplicate(),
		}

	static func from_dict(d: Dictionary) -> QuestRuntime:
		var q := QuestRuntime.new()
		q.id = d.get("id", &"")
		q.state = d.get("state", QuestState.ACTIVE)
		q.objectives = d.get("objectives", {}).duplicate(true)
		q.started_day = d.get("started_day", 0)
		q.order = int(d.get("order", -1))
		q.meta = d.get("meta", {}).duplicate()
		return q


## The acting player's quest row (MP3). Shared fallback when no world is up.
func state(player_id: StringName = &"") -> PlayerState:
	return PlayerRegistry.state(player_id)


func _log() -> Dictionary:
	var q: Dictionary = state().quests
	for key in ["active", "flags", "completed_days", "pending_rewards"]:
		if not q.has(key): q[key] = {}
	for key in ["completed", "failed", "offered"]:
		if not q.has(key): q[key] = []
	return q


var active_quests: Dictionary:
	get: return _log()["active"]
	set(value): _log()["active"] = value


var completed_quests: Array:
	get: return _log()["completed"]
	set(value): _log()["completed"] = value


var failed_quests: Array:
	get: return _log()["failed"]
	set(value): _log()["failed"] = value


var offered_quests: Array:
	get: return _log()["offered"]
	set(value): _log()["offered"] = value


var quest_flags: Dictionary:
	get: return _log()["flags"]
	set(value): _log()["flags"] = value


## Absolute completion day per quest; completed_quests remains the history used by dialogue and map conditions.
var completed_days: Dictionary:
	get: return _log()["completed_days"]
	set(value): _log()["completed_days"] = value


## quest id -> {item id: amount} still owed. Successful deliveries are removed before another claim can run.
var pending_rewards: Dictionary:
	get: return _log()["pending_rewards"]
	set(value): _log()["pending_rewards"] = value


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.lua_event.connect(_on_lua_event)
	EventBus.lua_reloaded.connect(_on_lua_reloaded)
	EventBus.day_started.connect(_on_day_started)
	EventBus.new_game_started.connect(reset)
	EventBus.player_inventory_changed.connect(_on_inventory_changed)
	EventBus.load_completed.connect(_on_load_completed)
	EventBus.item_gained.connect(_on_item_gained)
	EventBus.crop_planted.connect(_on_crop_planted)
	EventBus.crop_watered.connect(_on_crop_watered)
	EventBus.crop_harvested.connect(_on_crop_harvested)
	EventBus.zone_entered.connect(_on_zone_entered)
	EventBus.area_changed.connect(_on_area_changed)
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.npc_meeting_started.connect(_on_npc_meeting_started)
	EventBus.animal_adopted.connect(_on_animal_adopted)
	EventBus.animal_fed.connect(_on_animal_fed)
	EventBus.animal_product_collected.connect(_on_animal_product_collected)
	EventBus.building_built.connect(_on_building_built)
	EventBus.enemy_defeated.connect(_on_enemy_defeated)
	EventBus.recipe_crafted.connect(_on_recipe_crafted)
	EventBus.quest_completed.connect(_on_quest_completed_signal)
	EventBus.resource_node_depleted.connect(_on_resource_depleted)
	EventBus.game_event.connect(_on_game_event)
	EventBus.furniture_changed.connect(_on_furniture_changed)
	EventBus.hygge_changed.connect(_on_hygge_changed)
	EventBus.home_upgraded.connect(_on_home_upgraded)
	EventBus.friend_changed.connect(_on_friend_changed)


## A new run forgets progress and rewards, but keeps the definitions registered by LuaRuntime at boot (and the state queries the
## furniture / home / social managers registered: they belong to the game, not to the run).
func reset() -> void:
	if not NetAuthority.can_write(): return
	_reward_owners.clear()
	_refresh_owners.clear()
	active_quests.clear()
	completed_quests.clear()
	failed_quests.clear()
	offered_quests.clear()
	completed_days.clear()
	pending_rewards.clear()
	_claim_again = false
	_missing.clear()
	_reward_claim_queued = false
	_refresh_queued = false
	_accept_counter = 0
	quest_flags.clear()


# =============================================================================================== definitions

func register_quest_from_lua(quest_data: Dictionary) -> void:
	var quest_id: StringName = quest_data.get("id", &"")
	if quest_id == &"":
		push_error("Lua quest is missing an id")
		return
	# Lua defines availability; we only store the definition cache
	quest_defs[quest_id] = quest_data
	_objective_cache.erase(str(quest_id))
	_giver_index_size = -1
	if str(quest_data.get("source_path", "")) != "":
		_report_binding_findings(quest_data)


## LuaRuntime re-read the files (F9): the definition of a quest whose file is gone or renamed is dropped (it would stay
## registered and, without its is_available hook, always available). Definitions registered by code (no source_path) are
## kept, and the progress of a quest is never touched; the objective cache is rebuilt on demand.
func _on_lua_reloaded() -> void:
	for quest_id in quest_defs.keys():
		if str((quest_defs[quest_id] as Dictionary).get("source_path", "")) != "" and not LuaRuntime.has_quest(str(quest_id)):
			quest_defs.erase(quest_id)
	_objective_cache.clear()


func get_quest_def(quest_id: StringName) -> Dictionary:
	return quest_defs.get(quest_id, {})


## State queries (on = "state"): the owner of the data registers `query: Callable(objective_def: Dictionary) -> int` under the query name and
## the answer is the progress COUNT (a threshold query answers 1 when it holds, 0 when not). Without a registration the four built-in names
## ask the owner autoload late bound: FurnitureManager.count_placed_by_rarity(rarities) / hygge_level_index(), HomeManager.tier (else the world
## flag home_tier), SocialManager.hearts(npc) (else the flag friend_<npc>); no manager means 0.
func register_state_query(query_name: StringName, query: Callable) -> void:
	_state_queries[str(query_name)] = query


func unregister_state_query(query_name: StringName) -> void:
	_state_queries.erase(str(query_name))


func known_state_queries() -> Array[String]:
	var out: Array[String] = []
	for query_name in STATE_QUERIES:
		out.append(str(query_name))
	for query_name in _state_queries:
		if not (str(query_name) in out):
			out.append(str(query_name))
	return out


## The binding lint of one definition (what LuaRuntime hands to register_quest_from_lua): a list of {path, line, rule = "quest_binding",
## token, message}; empty = every objective can be completed with the vocabulary above. Findings of file-based definitions are also
## appended to LuaRuntime.lint_report when the quest is registered.
func validate_definition(def: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var path := str(def.get("source_path", ""))
	var qid := str(def.get("id", ""))
	var add := func(token: String, message: String) -> void:
		out.append({"path": path, "line": 0, "rule": "quest_binding", "token": token, "message": "quest `%s`: %s" % [qid, message]})
	if qid == "":
		add.call("id", "the quest has no id")
	var objectives: Variant = def.get("objectives", [])
	if not (objectives is Array) and not (objectives is Dictionary and (objectives as Dictionary).is_empty()):
		add.call("objectives", "`objectives` must be a list of tables")
	var list: Array = _objective_list(def)
	var ids := {}
	for od_variant in list:
		if not (od_variant is Dictionary):
			add.call("objectives", "an objective is not a table")
			continue
		_lint_objective(od_variant, ids, add)
	var rewards := _Data.dict(def.get("rewards", {}))
	if rewards.has("gold") and (not _is_number(rewards["gold"]) or _Data.int_of(rewards["gold"]) < 0):
		add.call("rewards.gold", "gold must be a number >= 0")
	for reward_field in ["items", "friendship"]:
		var table: Variant = rewards.get(reward_field, {})
		if not (table is Dictionary):
			if not (table is Array and (table as Array).is_empty()):
				add.call("rewards." + reward_field, "`%s` must be a table { id = n }" % reward_field)
			continue
		for key in table:
			var n := _Data.int_of(table[key], -1)
			var top := FRIEND_CAP if reward_field == "friendship" else 999999
			if not _is_number(table[key]) or n < 1 or n > top:
				add.call("rewards.%s.%s" % [reward_field, key], "%s of `%s` must be a whole number 1..%d" % [reward_field, key, top])
	var meta := _Data.dict(def.get("meta", {}))
	if meta.has("tag") and not (str(meta["tag"]) in QUEST_TAGS):
		add.call("meta.tag", "tag `%s` is not one of %s" % [meta["tag"], ", ".join(QUEST_TAGS)])
	if meta.has("cooldown_days") and (not _is_number(meta["cooldown_days"]) or _Data.int_of(meta["cooldown_days"]) < 0):
		add.call("meta.cooldown_days", "cooldown_days must be a number >= 0")
	return out


func _lint_objective(od: Dictionary, ids: Dictionary, add: Callable) -> void:
	var oid := str(od.get("id", ""))
	if oid == "" or not _is_id(oid):
		add.call("id", "objective id `%s` must be lower-case letters, digits and underscores" % oid)
	elif ids.has(oid):
		add.call(oid, "objective id `%s` is used twice" % oid)
	ids[oid] = true
	var target_value: Variant = od.get("target", 1)
	if not _is_number(target_value) or _Data.int_of(target_value, 0) < 1:
		add.call(oid, "objective `%s`: target must be a number >= 1" % oid)
	var on := str(od.get("on", ""))
	var known_on := on == "" or on == "manual" or on == "state" or on == "game_event" or FILTERS.has(on) or GAME_EVENT_SUGAR.has(on)
	if not known_on:
		add.call(oid, "objective `%s`: on = \"%s\" is not in the binding vocabulary" % [oid, on])
		return
	for field in REQUIRED_FIELDS.get(on, []):
		if str(od.get(field, "")) == "":
			add.call(oid, "objective `%s`: on = \"%s\" needs the field `%s`" % [oid, on, field])
	if od.has("any_of"):
		var any_of := _Data.strings(od["any_of"])
		if on != "dialogue_started" or any_of.is_empty():
			add.call(oid, "objective `%s`: any_of belongs to on = \"dialogue_started\" and needs at least one npc id" % oid)
		elif _Data.int_of(target_value, 1) > any_of.size():
			add.call(oid, "objective `%s`: target %d is more than the %d npcs of any_of (each counts once)" % [oid, _Data.int_of(target_value, 1), any_of.size()])
	if bool(od.get("have", false)) and (on != "item_gained" or str(od.get("item", "")) == ""):
		add.call(oid, "objective `%s`: have = true belongs to on = \"item_gained\" with an item" % oid)
	if od.has("completed_flag") and (not (od.completed_flag is String) or not _is_id(str(od.completed_flag))):
		add.call(oid, "objective `%s`: completed_flag must name a saved flag" % oid)
	if od.has("needs"):
		var needs: Variant = od["needs"]
		if not (needs is Dictionary) or (needs as Dictionary).is_empty():
			add.call(oid, "objective `%s`: needs must be a table { item = n }" % oid)
		else:
			for item_id in needs:
				if not _is_number(needs[item_id]) or _Data.int_of(needs[item_id]) < 1:
					add.call(oid, "objective `%s`: needs.%s must be a number >= 1" % [oid, item_id])
	if bool(od.get("consume", false)) and not od.has("needs"):
		add.call(oid, "objective `%s`: consume = true needs `needs = { item = n }`" % oid)
	if on == "game_event" or GAME_EVENT_SUGAR.has(on):
		if od.has("min_level") and not _is_number(od["min_level"]):
			add.call(oid, "objective `%s`: min_level must be a number" % oid)
		if od.has("match") and not (od["match"] is Dictionary):
			add.call(oid, "objective `%s`: match must be a table { npc = \"..\" }" % oid)
	if on == "state":
		var query_name := str(od.get("state", ""))
		if query_name != "" and not STATE_QUERIES.has(query_name) and not _state_queries.has(query_name):
			add.call(oid, "objective `%s`: unknown state query `%s` (known: %s)" % [oid, query_name, ", ".join(known_state_queries())])
		elif STATE_QUERIES.has(query_name):
			for field in (STATE_QUERIES[query_name] as Dictionary)["fields"]:
				if str(od.get(field, "")) == "":
					add.call(oid, "objective `%s`: state `%s` needs the field `%s`" % [oid, query_name, field])
			if bool((STATE_QUERIES[query_name] as Dictionary)["threshold"]) and _Data.int_of(target_value, 1) != 1:
				add.call(oid, "objective `%s`: state `%s` is a threshold: target must be 1" % [oid, query_name])


func _report_binding_findings(def: Dictionary) -> void:
	var findings := validate_definition(def)
	if findings.is_empty():
		return
	var runtime := get_node_or_null("/root/LuaRuntime")
	if runtime == null:
		return
	var report: Variant = runtime.get("lint_report")
	if report is Array:
		for finding in findings:
			(report as Array).append(finding)


## The objectives of a definition as a list, however the Lua reader handed them over (an empty table arrives as a Dictionary).
func _objective_list(def: Dictionary) -> Array:
	var raw: Variant = def.get("objectives", [])
	return raw if raw is Array else []


## objective id (String) -> its Lua table, cached per definition (the cache notices a replaced definition).
func _objective_defs(quest_id: Variant) -> Dictionary:
	var key := str(quest_id)
	var def: Dictionary = quest_defs.get(StringName(key), {})
	var cached: Variant = _objective_cache.get(key)
	if cached is Dictionary and is_same((cached as Dictionary)["def"], def):
		return (cached as Dictionary)["map"]
	var map := {}
	for od in _objective_list(def):
		if od is Dictionary and str((od as Dictionary).get("id", "")) != "":
			map[str((od as Dictionary)["id"])] = od
	_objective_cache[key] = {"def": def, "map": map}
	return map


# =============================================================================================== offers

func offer_quest(quest_id: StringName) -> void:
	if get_quest_def(quest_id).is_empty() or not _can_start(quest_id) or not _requirements_met(quest_id) or quest_id in offered_quests:
		return
	offered_quests.append(quest_id)
	EventBus.quest_offered.emit(PlayerRegistry.acting_id(), quest_id)


## The quests `npc_id` can give RIGHT NOW, in the order of lua/config/npcs.lua `quests_offered` (quests that only name the giver in their own
## meta follow in id order): is_available true, not active, not done (a repeatable quest again after its cooldown), requires_zone unlocked.
## P14 shows the "!" bubble from this list and V6's mailbox / notice board use offerable_for.
func offerable(npc_id: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	for quest_id in _quests_of_giver(str(npc_id)):
		if _is_offerable_now(quest_id):
			out.append(quest_id)
	return out


## offerable() of several givers at once: [{quest_id, giver}], the givers in the order given.
func offerable_for(givers: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for giver in givers:
		for quest_id in offerable(giver):
			out.append({"quest_id": quest_id, "giver": StringName(str(giver))})
	return out


func _quests_of_giver(giver: String) -> Array[StringName]:
	var out: Array[StringName] = []
	if giver == "":
		return out
	var runtime := get_node_or_null("/root/LuaRuntime")
	var row: Variant = runtime.call("get_npc", giver) if runtime != null else {}
	for q in _Data.strings(_Data.dict(row).get("quests_offered", [])):
		var quest_id := StringName(q)
		var meta_giver := str(_Data.dict(get_quest_def(quest_id).get("meta", {})).get("giver", ""))
		if quest_defs.has(quest_id) and (meta_giver == "" or meta_giver == giver) and not (quest_id in out):
			out.append(quest_id)
	for q in _quests_naming_giver(giver):
		if quest_defs.has(StringName(q)) and not (StringName(q) in out):
			out.append(StringName(q))
	return out


## The quests whose own meta names `giver`, in id order. Every NPC asks offerable() on each broadcast, so the scan over every definition runs once per
## set of definitions (rebuilt after a registration, or when the number of definitions changed).
func _quests_naming_giver(giver: String) -> Array:
	if _giver_index_size != quest_defs.size():
		_giver_index = {}
		for quest_id in quest_defs:
			var named := str(_Data.dict(_Data.dict(quest_defs[quest_id]).get("meta", {})).get("giver", ""))
			if named != "":
				if not _giver_index.has(named):
					_giver_index[named] = []
				(_giver_index[named] as Array).append(str(quest_id))
		for named in _giver_index:
			(_giver_index[named] as Array).sort()
		_giver_index_size = quest_defs.size()
	return _giver_index.get(giver, [])


## One quest of offerable(): defined, not active, startable (not done / cooled down, Lua is_available) and its zone unlocked. P14's offer
## choice and V6's notice board ask this before they show an accept button.
func is_offerable(quest_id: StringName) -> bool:
	return _is_offerable_now(quest_id)


func _is_offerable_now(quest_id: StringName) -> bool:
	return not get_quest_def(quest_id).is_empty() and not (quest_id in active_quests) and _can_start(quest_id) and _requirements_met(quest_id)


## meta.requires_zone: the zone has been unlocked (entered once, or unlocked by a quest hook). Only offers read it.
func register_offer_gate(quest_id: StringName,query: Callable) -> void:
	if query.is_valid():_offer_gates[str(quest_id)] = query
	else:_offer_gates.erase(str(quest_id))

func _requirements_met(quest_id: StringName) -> bool:
	var zone := str(_Data.dict(get_quest_def(quest_id).get("meta", {})).get("requires_zone", ""))
	if zone != "" and not GameManager.is_zone_unlocked(StringName(zone)):return false
	return _offer_allowed(quest_id)

func _offer_allowed(quest_id: StringName) -> bool:
	var query: Callable = _offer_gates.get(str(quest_id),Callable())
	return not query.is_valid() or bool(query.call())


# =============================================================================================== accept / progress / complete

func accept_quest(quest_id: StringName) -> bool:
	if not _can_start(quest_id) or not _offer_allowed(quest_id):
		return false

	var def := get_quest_def(quest_id)
	if def.is_empty():
		push_warning("Unknown quest: %s" % quest_id)
		return false

	_activate(quest_id, def)
	return true


## The part of accept_quest after the checks (the table-driven completability test also starts quests whose hidden Lua gate it cannot open).
func _activate(quest_id: StringName, def: Dictionary) -> void:
	var rt := QuestRuntime.new()
	rt.id = quest_id
	rt.state = QuestState.ACTIVE
	rt.started_day = GameManager.day
	rt.order = _accept_counter
	_accept_counter += 1
	rt.meta = _Data.dict(def.get("meta", {})).duplicate()

	for obj in _objective_list(def):
		if not (obj is Dictionary) or str((obj as Dictionary).get("id", "")) == "":
			continue
		rt.objectives[(obj as Dictionary)["id"]] = {
			"current": 0,
			"target": maxi(_Data.int_of((obj as Dictionary).get("target", 1), 1), 1),
			"done": false,
		}

	active_quests[quest_id] = rt
	offered_quests.erase(quest_id)
	EventBus.quest_accepted.emit(PlayerRegistry.acting_id(), quest_id)
	EventBus.notification_posted.emit(
		tr("NOTIF_QUEST_ACCEPTED_TITLE"),
		get_title(quest_id),
		"quest"
	)
	_lua_notify("quest_accepted", quest_id)
	# what the player already owns / stands in counts from the first moment (have and state objectives)
	if quest_id in active_quests:
		_refresh_quest(quest_id)


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
	EventBus.quest_objective_updated.emit(PlayerRegistry.acting_id(), quest_id, objective_id, obj["current"], obj["target"])
	_check_completion(quest_id)


## Progress that is a VALUE (have / state objectives): set to `value` (0..target), done once the target is reached. Unchanged = no signal.
func _set_progress(quest_id: StringName, objective_id: Variant, value: int) -> void:
	if quest_id not in active_quests:
		return
	var rt: QuestRuntime = active_quests[quest_id]
	if not rt.objectives.has(objective_id):
		return
	var obj: Dictionary = rt.objectives[objective_id]
	if bool(obj["done"]):
		return
	var current := clampi(value, 0, int(obj["target"]))
	if current == int(obj["current"]):
		return
	obj["current"] = current
	if current >= int(obj["target"]):
		obj["done"] = true
	EventBus.quest_objective_updated.emit(PlayerRegistry.acting_id(), quest_id, StringName(str(objective_id)), current, obj["target"])
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
	var owner := _owner_ticket(PlayerRegistry.acting_id())
	if owner.is_empty() or not _owner_current(owner): return
	if quest_id not in active_quests:
		return
	var def := get_quest_def(quest_id)
	var runtime: QuestRuntime = active_quests[quest_id]
	var rewards: Dictionary = preload("res://scripts/data/quest_rewards.gd").resolve(def,runtime.meta)

	# Commit completion before grants: inventory and gold listeners may synchronously call back into the quest manager.
	active_quests.erase(quest_id)
	completed_quests.erase(quest_id)               # a repeated completion is the most recent one
	completed_quests.append(quest_id)
	completed_days[quest_id] = GameManager.total_day()
	var owed: Dictionary = pending_rewards.get(quest_id, {})
	var items := _Data.int_map(rewards.get("items", {}))
	for item_id in items:
		var amount := int(items[item_id])
		if amount > 0:
			owed[str(item_id)] = int(owed.get(str(item_id), 0)) + amount
	if not owed.is_empty():
		pending_rewards[quest_id] = owed
	if rewards.has("gold"):
		EconomyManager.add_gold(_Data.int_of(rewards["gold"]))
	if not _owner_current(owner): return
	_grant_friendship(_Data.int_map(rewards.get("friendship", {})), owner)
	if not _owner_current(owner): return
	claim_rewards()
	if not _owner_current(owner): return
	EventBus.quest_completed.emit(owner.id, quest_id)
	if not _owner_current(owner): return
	EventBus.notification_posted.emit(
		tr("NOTIF_QUEST_COMPLETED_TITLE"),
		get_title(quest_id),
		"quest_done"
	)
	if not _owner_current(owner): return
	_lua_notify("quest_completed", quest_id)


## rewards.friendship = { npc = hearts }. SocialManager (S-core, the one writer of hearts) when it exists; else the world flag friend_<npc>
## (whole hearts, capped at FRIEND_CAP) and EventBus.friend_changed when the hearts changed.
func _grant_friendship(hearts_by_npc: Dictionary, owner: Dictionary) -> void:
	for npc in hearts_by_npc:
		if not _owner_current(owner): return
		var hearts := int(hearts_by_npc[npc])
		if hearts <= 0:
			continue
		var social := _Svc.node("SocialManager")
		if social != null and social.has_method("add_hearts"):
			social.call("add_hearts", StringName(str(npc)), hearts, &"quest")
			continue
		var flag := StringName("friend_%s" % npc)
		var before := GameManager.flag_int(flag, 0)
		var after := mini(before + hearts, FRIEND_CAP)
		if after == before:
			continue
		GameManager.set_flag(flag, after)
		if not _owner_current(owner): return
		EventBus.friend_changed.emit(owner.id, StringName(str(npc)), after)


## Delivers what fits, retaining the rest in the save. Called again after inventory changes and successful loads. A backpack stack
## that only partly fits is delivered in part; a piece its store refuses (a garment already owned, furniture at its cap) goes through
## LootService.deliver, which sells such a duplicate at once (SYS-16), so it is never owed forever.
## Returns true when nothing remains owed. The guard prevents item-gained listeners from claiming a grant twice; a claim asked for
## during a pass (a reward that completed another quest owes that quest's rewards) runs as one more pass before the guard is released.
func claim_rewards() -> bool:
	var owner := _owner_ticket(PlayerRegistry.acting_id())
	if owner.is_empty() or not _owner_current(owner): return false
	if _claiming_rewards:
		_claim_again = true
		return pending_rewards.is_empty()
	_claiming_rewards = true
	_claim_again = true
	while _claim_again and _owner_current(owner):
		_claim_again = false
		_claim_pass(owner)
	_claiming_rewards = false
	# A synchronous load can enqueue a replacement row while this owner runs.
	# Retain it until genuine unwind rather than polling a live claim guard.
	if not _reward_owners.is_empty() and not _reward_claim_queued:
		_reward_claim_queued = true
		_run_reward_claim.call_deferred()
	return _owner_current(owner) and pending_rewards.is_empty()


func _claim_pass(owner: Dictionary) -> void:
	for quest_id in pending_rewards.keys():
		if not _owner_current(owner): return
		if not pending_rewards.has(quest_id):
			continue
		var owed: Dictionary = pending_rewards[quest_id]
		for item_id in owed.keys():
			if not _owner_current(owner): return
			var amount := int(owed[item_id])
			var give := _claimable(StringName(item_id), amount)
			if give <= 0:
				continue
			# item_gained listeners may save immediately: at that point the grant is owned and must no longer be owed.
			if give < amount:
				owed[item_id] = amount - give
			else:
				owed.erase(item_id)
			var delivered := _deliver_reward(StringName(item_id), give)
			# Delivery flushes public observers. Its already committed grant stays
			# accounted on the origin, but no later grant or row lookup may borrow it.
			if not _owner_current(owner): return
			if not delivered: owed[item_id] = amount
		if owed.is_empty():
			pending_rewards.erase(quest_id)


## How many of an owed reward to hand over now: all of it when it fits, else what the backpack has room for; a piece with a store of its
## own is handed over whole (the store takes it, or LootService sells the duplicate).
func _claimable(item_id: StringName, amount: int) -> int:
	if EconomyManager.can_add_item(item_id, amount):
		return amount
	if _Kinds.storage_of(item_id) == _Kinds.BACKPACK:
		return mini(amount, EconomyManager.backpack_room_for(item_id))
	return amount


func _deliver_reward(item_id: StringName, amount: int) -> bool:
	var loot := _Svc.node("LootService")
	if loot != null and loot.has_method("deliver"):
		return bool(_Data.dict(loot.call("deliver", item_id, amount)).get("ok", false))
	return EconomyManager.add_item(item_id, amount)


func _on_inventory_changed(player_id: StringName, _inventory: Dictionary) -> void:
	_for_event_owner(player_id, func():
		_queue_reward_claim()
		_queue_refresh())


func _on_load_completed(_slot: int) -> void:
	_queue_reward_claim()
	# every section of the save is applied now (home, furniture, social come after the quests): have and state objectives read the new world
	refresh_objectives()


func _queue_reward_claim() -> void:
	if not NetAuthority.can_write(): return
	if pending_rewards.is_empty(): return
	var id := PlayerRegistry.acting_id()
	var ticket := _owner_ticket(id)
	if ticket.is_empty(): return
	# A load may replace this row before its old deferred ticket dispatches.
	if _reward_owners.has(id) and _owner_current(_reward_owners[id]): return
	_reward_owners[id] = ticket
	if _claiming_rewards or _reward_claim_queued: return
	_reward_claim_queued = true
	_run_reward_claim.call_deferred()


func _run_reward_claim() -> void:
	var owners := _reward_owners
	_reward_owners = {}
	_reward_claim_queued = false
	for ticket: Dictionary in owners.values():
		if _owner_current(ticket): PlayerRegistry.for_player(ticket.id, claim_rewards)


func fail_quest(quest_id: StringName) -> void:
	if quest_id not in active_quests:
		return
	active_quests.erase(quest_id)
	failed_quests.append(quest_id)
	EventBus.quest_failed.emit(PlayerRegistry.acting_id(), quest_id)
	_lua_notify("quest_failed", quest_id)


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


func _on_day_started(_day: int, _season: StringName) -> void:
	if not NetAuthority.can_write(): return
	for quest_id in active_quests.keys():
		if quest_id in active_quests:
			_lua_notify("day_started", quest_id)


# =============================================================================================== event bindings

func _on_item_gained(player_id: StringName, item_id: StringName, amount: int) -> void:
	var row := PlayerRegistry.peek_state(player_id)
	_for_event_owner(player_id, func():
		_dispatch(&"item_gained", {"item": str(item_id), "amount": amount})
		if PlayerRegistry.peek_state(player_id) == row: _queue_refresh())


func _on_crop_planted(plot_id: StringName, crop_id: StringName) -> void:
	_dispatch(&"crop_planted", {"plot": str(plot_id), "crop": str(crop_id)})


func _on_crop_watered(plot_id: StringName) -> void:
	_dispatch(&"crop_watered", {"plot": str(plot_id)})


func _on_crop_harvested(plot_id: StringName, crop_id: StringName, amount: int) -> void:
	_dispatch(&"crop_harvested", {"plot": str(plot_id), "crop": str(crop_id), "amount": amount})


func _on_zone_entered(zone_id: StringName) -> void:
	_dispatch(&"zone_entered", {"zone": str(zone_id)})


func _on_area_changed(area_id: StringName) -> void:
	_dispatch(&"area_changed", {"area": str(area_id)})


func _on_dialogue_started(npc_id: StringName, dialogue_id: StringName) -> void:
	_dispatch(&"dialogue_started", {"npc": str(npc_id), "dialogue": str(dialogue_id)})


## Opt-in physical objectives retain the dialogue binding vocabulary while
## legacy talk/show/proof objectives retain their existing event contract.
## A portrait/giver string cannot authorize a delivery: identity and ownership
## come from the actor that is currently holding the player in a conversation.
func _on_npc_meeting_started(actor: Node) -> void:
	if not actor is Npc2D or not actor.is_inside_tree() or actor.is_queued_for_deletion() or not actor.is_talking:
		return
	var owner_id := PlayerRegistry.registered_id(actor._talk_player)
	if owner_id == &"":
		return
	PlayerRegistry.for_player(owner_id, func():
		_dispatch(&"dialogue_started", {"npc": str(actor.npc_id), "dialogue": str(actor.dialogue_id), "meeting_actor": actor}))


func _on_animal_adopted(animal_id: StringName, species: StringName) -> void:
	_dispatch(&"animal_adopted", {"animal": str(animal_id), "species": str(species)})
	_queue_refresh()


func _on_animal_fed(animal_id: StringName, food_id: StringName) -> void:
	_dispatch(&"animal_fed", {"animal": str(animal_id), "food": str(food_id)})


func _on_animal_product_collected(animal_id: StringName, product_id: StringName, amount: int) -> void:
	_dispatch(&"animal_product_collected", {"animal": str(animal_id), "product": str(product_id), "amount": amount})


func _on_building_built(building_id: StringName, building_type: StringName) -> void:
	_dispatch(&"building_built", {"building": str(building_id), "type": str(building_type)})
	_queue_refresh()


func _on_enemy_defeated(enemy_id: StringName, kind: StringName, _loot: Array) -> void:
	_dispatch(&"enemy_defeated", {"enemy": str(enemy_id), "kind": str(kind)})


func _on_recipe_crafted(recipe_id: StringName, amount: int) -> void:
	_dispatch(&"recipe_crafted", {"recipe": str(recipe_id), "amount": amount})


## Another quest was completed (this node emits the signal itself): the finished quest is no longer active, so it never counts for itself.
func _on_quest_completed_signal(player_id: StringName, quest_id: StringName) -> void:
	_for_event_owner(player_id, func():
		var meta := _Data.dict(get_quest_def(quest_id).get("meta", {}))
		_dispatch(&"quest_completed", {"quest": str(quest_id), "category": str(meta.get("category", ""))}))


func _on_game_event(event_name: StringName, payload: Dictionary) -> void:
	_dispatch(&"game_event", {"event": str(event_name), "payload": payload})


## The old id convention (objectives WITHOUT `on`): collect_<item> is fed by what a resource node dropped. Objectives with an `on` never
## read it (their item_gained already counts the drop: this is what the old double counting was).
func _on_resource_depleted(_node_id: StringName, loot: Array) -> void:
	for entry in loot:
		if entry is Dictionary:
			_dispatch(&"resource_loot", {"item": str((entry as Dictionary).get("id", "")), "amount": int((entry as Dictionary).get("amount", 1))})


func _on_furniture_changed(_reason: StringName) -> void:
	refresh_objectives()


func _on_hygge_changed(_score: int, _level: StringName) -> void:
	refresh_objectives()


func _on_home_upgraded(_old_tier: int, _new_tier: int) -> void:
	refresh_objectives()


func _on_friend_changed(player_id: StringName, _npc_id: StringName, _hearts: int) -> void:
	_for_event_owner(player_id, refresh_objectives)


## One event, every active quest, every open objective. A turn-in (after_others) is judged on the state BEFORE the event, so the progress this
## very event made never lets it through; keys() copies everywhere because progress can complete (and erase) a quest in the middle of the loop.
func _dispatch(kind: StringName, ctx: Dictionary) -> void:
	if not NetAuthority.can_write(): return
	if active_quests.is_empty():
		return
	_dispatch_depth += 1
	for quest_id in active_quests.keys():
		if active_quests.has(quest_id):
			_dispatch_to_quest(quest_id, kind, ctx)
	_dispatch_depth -= 1
	_flush_missing()


func _dispatch_to_quest(quest_id: StringName, kind: StringName, ctx: Dictionary) -> void:
	var rt: QuestRuntime = active_quests[quest_id]
	var defs := _objective_defs(quest_id)
	var others_done := _non_turn_ins_done(rt, defs)
	var hits: Array = []
	for objective_id in rt.objectives.keys():
		var obj: Dictionary = rt.objectives[objective_id]
		if bool(obj.get("done", false)):
			continue
		var od: Dictionary = defs.get(str(objective_id), {})
		var step := _step_for(od, str(objective_id), kind, ctx, obj)
		if step <= 0:
			continue
		if bool(od.get("after_others", false)) and not others_done:
			continue
		hits.append([objective_id, step, od])
	for hit in hits:
		if not active_quests.has(quest_id) or active_quests[quest_id] != rt:
			return
		var od_hit: Dictionary = hit[2]
		_apply_hit(quest_id, hit[0], int(hit[1]), od_hit, ctx)


## Progress one event gives to one objective: 0 = the event does not bind to it.
func _step_for(od: Dictionary, objective_id: String, kind: StringName, ctx: Dictionary, obj: Dictionary) -> int:
	var on := str(od.get("on", ""))
	if on == "":
		return _legacy_step(objective_id, kind, ctx)
	if on == "manual" or on == "state" or bool(od.get("have", false)):
		return 0                      # finished by complete_manual / evaluated by refresh_objectives, never counted from events
	var step := _amount_of(od, ctx)
	if step <= 0:
		return 0
	if on == "game_event" or GAME_EVENT_SUGAR.has(on):
		return step if kind == &"game_event" and _game_event_matches(od, on, ctx) else 0
	if str(kind) != on:
		return 0
	if on == "dialogue_started":
		# Physical and ordinary starts are disjoint, so neither can double count
		# an objective when a real NPC emits both events.
		if bool(od.get("requires_meeting", false)) != ctx.has("meeting_actor"):
			return 0
		var npc := str(ctx.get("npc", ""))
		var any_of := _Data.strings(od.get("any_of", []))
		if not any_of.is_empty():
			if not (npc in any_of) or npc in _Data.strings(obj.get("seen", [])):
				return 0
		elif not _csv_contains(od.get("npc", ""), npc):
			return 0
		return step if _csv_contains(od.get("dialogue", ""), str(ctx.get("dialogue", ""))) else 0
	for field in FILTERS.get(on, []):
		if not _csv_contains(od.get(field, ""), str(ctx.get(field, ""))):
			return 0
	return step


func _amount_of(od: Dictionary, ctx: Dictionary) -> int:
	if od.has("amount"):
		return _Data.int_of(od["amount"], 1)
	return int(ctx["amount"]) if ctx.has("amount") else 1


func _legacy_step(objective_id: String, kind: StringName, ctx: Dictionary) -> int:
	if kind == &"crop_harvested" and (objective_id == "harvest_%s" % ctx.get("crop", "") or objective_id == "harvest_any"):
		return int(ctx.get("amount", 1))
	if kind in [&"item_gained", &"resource_loot"] and objective_id == "collect_%s" % ctx.get("item", ""):
		return int(ctx.get("amount", 1))
	return 0


func _game_event_matches(od: Dictionary, on: String, ctx: Dictionary) -> bool:
	var wanted := str(od.get("event", "")) if on == "game_event" else on
	if wanted == "" or wanted != str(ctx.get("event", "")):
		return false
	var payload := _Data.dict(ctx.get("payload", {}))
	if od.has("rarity") and not _csv_contains(od["rarity"], str(payload.get("rarity", ""))):
		return false
	if od.has("min_level"):
		var level: Variant = payload.get("level")
		if not _is_number(level) or float(level) < float(_Data.num(od["min_level"])):
			return false
	var wanted_entries := _Data.dict(od.get("match", {}))
	for key in wanted_entries:
		if not payload.has(key) or not _same_value(payload[key], wanted_entries[key]):
			return false
	if GAME_EVENT_SUGAR.has(on):
		for field in GAME_EVENT_SUGAR[on]:
			if od.has(field) and not _csv_contains(od[field], str(payload.get(field, ""))):
				return false
	return true


## Live only after the economy's silent deductions and before public observers.
## This is not serialized, not an EventBus credential and not a caller occurrence.
var _living_delivery_commit: Dictionary = {}


func living_delivery_context(consumer: Node) -> Dictionary:
	if consumer != get_node_or_null("/root/SocialManager") or _living_delivery_commit.is_empty():
		return {}
	var ctx := _living_delivery_commit
	_living_delivery_commit = {}
	var actor: Node = ctx.get("actor")
	if not actor is Npc2D or not actor.is_inside_tree() or actor.is_queued_for_deletion() or not actor.is_talking or str(actor.npc_id) != "smith_thorin":
		return {}
	var pid := PlayerRegistry.registered_id(actor._talk_player)
	if pid == &"" or pid != ctx.owner or PlayerRegistry.acting_id() != pid:
		return {}
	return {"actor": actor, "day": ctx.day}


## A matched event becomes progress. A delivery (`needs`) first checks and takes the goods: all of it in one commit with the progress.
func _apply_hit(quest_id: StringName, objective_id: Variant, step: int, od: Dictionary, ctx: Dictionary) -> void:
	var rt: QuestRuntime = active_quests[quest_id]
	var obj: Dictionary = rt.objectives[objective_id]
	var needs := _needs_of(od)
	if not needs.is_empty() and not EconomyManager.has_items(needs):
		_note_missing(needs)
		return
	var commit := func() -> void:
		# Only this shipped physical target-one consume source has day-unique
		# occurrences (seven-day cooldown). Do not generalize to gifts/cookies.
		if quest_id == &"dark_forest_mining" and str(objective_id) == "return_to_smith" and bool(od.get("consume", false)) and bool(od.get("requires_meeting", false)) and needs == {"iron_ore": 6, "amethyst": 2} and int(obj.get("target", 0)) == 1 and not bool(obj.get("done", false)):
			var actor: Node = ctx.get("meeting_actor")
			if actor is Npc2D and is_instance_valid(actor) and actor.is_inside_tree() and actor.is_talking and not actor.is_queued_for_deletion():
				var owner := PlayerRegistry.registered_id(actor._talk_player)
				if owner != &"" and owner == PlayerRegistry.acting_id() and str(actor.npc_id) == "smith_thorin":
					_living_delivery_commit = {"actor": actor, "owner": owner, "day": GameManager.total_day()}
					var social := get_node_or_null("/root/SocialManager")
					if social != null and social.has_method("living_record_delivery"):
						social.call("living_record_delivery", self)
					_living_delivery_commit = {}
		if not _Data.strings(od.get("any_of", [])).is_empty():
			var seen: Array = _Data.arr(obj.get("seen", []))
			seen.append(str(ctx.get("npc", "")))
			obj["seen"] = seen
		update_objective(quest_id, StringName(str(objective_id)), step)
	if bool(od.get("consume", false)) and not needs.is_empty():
		if not EconomyManager.consume_backpack_items(needs, commit):
			_note_missing(needs)
		return
	commit.call()


## A delivery that lacks its goods: the shortfall is gathered and told once when the event has been dispatched to every quest (SYS-11).
func _note_missing(needs: Dictionary) -> void:
	for item_id in needs:
		_missing[str(item_id)] = maxi(int(_missing.get(str(item_id), 0)), int(needs[item_id]))
	_flush_missing()


## One toast that names what is missing: "Gulerod 10 af 12". The generic text when every item is owned but cannot be handed over (a piece
## that is not in the backpack).
func _flush_missing() -> void:
	if _dispatch_depth > 0 or _missing.is_empty():
		return
	var needs := _missing
	_missing = {}
	var rows: Array[String] = []
	for item_id in needs:
		var have := EconomyManager.count_item(StringName(item_id))
		if have < int(needs[item_id]):
			var shown := tr(str(EconomyManager.item_def(item_id).get("name_key", "ITEM_%s" % item_id.to_upper())))
			rows.append(LocalizationManager.t("QUEST_NEEDS_ITEM_ROW_FMT", [shown, have, int(needs[item_id])]))
	var text := LocalizationManager.t("QUEST_NEEDS_ITEMS_FMT", [", ".join(rows)]) if not rows.is_empty() else tr("QUEST_NEEDS_ITEMS_TEXT")
	EventBus.notification_posted.emit(tr("QUEST_NEEDS_ITEMS_TITLE"), text, "quest")


## Every objective that is not a turn-in is done: the moment a turn-in (after_others) may count.
func _non_turn_ins_done(rt: QuestRuntime, defs: Dictionary) -> bool:
	for objective_id in rt.objectives:
		var od: Dictionary = defs.get(str(objective_id), {})
		if bool(od.get("after_others", false)):
			continue
		if not bool((rt.objectives[objective_id] as Dictionary).get("done", false)):
			return false
	return true


# =============================================================================================== have / state objectives

## Re-evaluates the derived objectives (have = true: the inventory count, on = "state": the query) of every active quest. Runs when a quest
## is accepted, on load, on the state signals and, coalesced to once per frame, after every inventory change; call it to settle a test.
func refresh_objectives() -> void:
	if not NetAuthority.can_write(): return
	_refresh_queued = false
	for quest_id in active_quests.keys():
		if active_quests.has(quest_id):
			_refresh_quest(quest_id)


func _queue_refresh() -> void:
	if not NetAuthority.can_write(): return
	if active_quests.is_empty(): return
	var id := PlayerRegistry.acting_id()
	var ticket := _owner_ticket(id)
	if ticket.is_empty(): return
	# A load may replace this row before its old deferred ticket dispatches.
	if _refresh_owners.has(id) and _owner_current(_refresh_owners[id]): return
	_refresh_owners[id] = ticket
	if _refresh_queued: return
	_refresh_queued = true
	_run_refresh.call_deferred()


func _run_refresh() -> void:
	var owners := _refresh_owners
	_refresh_owners = {}
	_refresh_queued = false
	for ticket: Dictionary in owners.values():
		if _owner_current(ticket): PlayerRegistry.for_player(ticket.id, refresh_objectives)


func _refresh_quest(quest_id: StringName) -> void:
	var rt: QuestRuntime = active_quests[quest_id]
	var defs := _objective_defs(quest_id)
	for objective_id in rt.objectives.keys():
		if not active_quests.has(quest_id) or active_quests[quest_id] != rt:
			return
		var obj: Dictionary = rt.objectives[objective_id]
		if bool(obj.get("done", false)):
			continue
		var od: Dictionary = defs.get(str(objective_id), {})
		var value := -1
		if str(od.get("on", "")) == "state":
			value = _state_value(od)
		elif bool(od.get("have", false)):
			value = _have_value(od)
		elif str(od.get("completed_flag", "")) != "":
			# Event objectives may also accept a permanent, previously earned
			# achievement on acceptance/load: the flag fills the objective, an unset one leaves the live event progress alone (SYS-05).
			if not bool(GameManager.get_flag(StringName(str(od.completed_flag)), false)):
				continue
			value = int(obj["target"])
		if value < 0:
			continue
		if bool(od.get("after_others", false)) and not _non_turn_ins_done(rt, defs):
			continue
		_set_progress(quest_id, objective_id, value)


func _have_value(od: Dictionary) -> int:
	return EconomyManager.count_item(StringName(str(od.get("item", ""))))


func _state_value(od: Dictionary) -> int:
	var query_name := str(od.get("state", ""))
	var registered: Variant = _state_queries.get(query_name)
	if registered is Callable and (registered as Callable).is_valid():
		return maxi(_Data.int_of((registered as Callable).call(od)), 0)
	return maxi(_builtin_state_value(query_name, od), 0)


func _builtin_state_value(query_name: String, od: Dictionary) -> int:
	match query_name:
		"buildings_owned":
			var husbandry := _Svc.node("AnimalHusbandry")
			if husbandry == null: return 0
			var count := 0
			for building in husbandry.buildings.values():
				if building.is_built and str(building.building_type) == str(od.get("type","")): count += 1
			return count
		"animals_owned":
			var husbandry := _Svc.node("AnimalHusbandry")
			return husbandry.get_all_animals().size() if husbandry != null else 0

		"placed_by_rarity":
			var furniture := _Svc.node("FurnitureManager")
			if furniture == null or not furniture.has_method("count_placed_by_rarity"):
				return 0
			return _Data.int_of(furniture.call("count_placed_by_rarity", _csv(od.get("rarity", ""))))
		"hygge_level_at_least":
			var furniture_level := _Svc.node("FurnitureManager")
			if furniture_level == null or not furniture_level.has_method("hygge_level_index"):
				return 0
			return 1 if _Data.int_of(furniture_level.call("hygge_level_index")) >= _Data.int_of(od.get("min_level", 0)) else 0
		"home_tier_at_least":
			return 1 if _home_tier() >= _Data.int_of(od.get("min_level", 1)) else 0
		"friend_hearts_at_least":
			return 1 if _hearts_of(str(od.get("npc", ""))) >= _Data.int_of(od.get("hearts", 1)) else 0
	return 0


func _home_tier() -> int:
	var home := _Svc.node("HomeManager")
	if home != null and home.get("tier") != null:
		return _Data.int_of(home.get("tier"), 1)
	return GameManager.flag_int(GameManager.FLAG_HOME_TIER, 1)


func _hearts_of(npc: String) -> int:
	var social := _Svc.node("SocialManager")
	if social != null and social.has_method("hearts"):
		return _Data.int_of(social.call("hearts", StringName(npc)))
	return GameManager.flag_int(StringName("friend_%s" % npc), 0)


# =============================================================================================== journal, tracker, text

## The HUD card: the active quests, oldest accepted first, at most `max_count`; never a completed or failed one; the order survives save / load.
func get_tracked(max_count: int = DEFAULT_TRACKED) -> Array[StringName]:
	var out: Array[StringName] = []
	for quest_id in get_active_ids():
		if out.size() >= max_count:
			break
		out.append(quest_id)
	return out


## The quest book, tab "Aktive": every active quest, oldest accepted first.
func get_active_ids() -> Array[StringName]:
	var rows: Array = []
	var index := 0
	for quest_id in active_quests:
		rows.append([(active_quests[quest_id] as QuestRuntime).order, index, StringName(str(quest_id))])
		index += 1
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var out: Array[StringName] = []
	for row in rows:
		out.append(row[2])
	return out


## The quest book, tab "Fuldført": every completed quest, the most recently completed first.
func get_completed_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in range(completed_quests.size() - 1, -1, -1):
		out.append(completed_quests[i])
	return out


func get_active_count() -> int:
	return active_quests.size()


func get_completed_count() -> int:
	return completed_quests.size()


## {current, target, done} of one objective of an ACTIVE quest ({} when it is not active / unknown).
func get_objective_progress(quest_id: StringName, objective_id: StringName) -> Dictionary:
	if not active_quests.has(quest_id):
		return {}
	var rt: QuestRuntime = active_quests[quest_id]
	return (rt.objectives.get(objective_id, {}) as Dictionary).duplicate()


## The objective the player should work on now: the first open one in Lua order (a turn-in only once nothing else is open).
func get_current_objective(quest_id: StringName) -> StringName:
	if not active_quests.has(quest_id):
		return &""
	var rt: QuestRuntime = active_quests[quest_id]
	var defs := _objective_defs(quest_id)
	var turn_in: StringName = &""
	for objective_id in rt.objectives:
		if bool((rt.objectives[objective_id] as Dictionary).get("done", false)):
			continue
		if bool((defs.get(str(objective_id), {}) as Dictionary).get("after_others", false)):
			if turn_in == &"":
				turn_in = StringName(str(objective_id))
			continue
		return StringName(str(objective_id))
	return turn_in


## Text of one objective: its description_key -> OBJ_<QUEST>_<OBJ> -> OBJ_<OBJ> -> the Lua `description` -> the readable id. Never a raw key.
func get_objective_text(quest_id: StringName, objective_id: StringName) -> String:
	if active_quests.has(quest_id):
		var runtime: QuestRuntime = active_quests[quest_id]
		var override_key := str(_Data.dict(runtime.meta.get("objective_keys",{})).get(str(objective_id),""))
		if override_key!="" and _has_key(override_key):return tr(override_key)
	var od: Dictionary = _objective_defs(quest_id).get(str(objective_id), {})
	var described := str(od.get("description_key", ""))
	if described != "" and _has_key(described):
		return tr(described)
	var specific := "OBJ_%s_%s" % [str(quest_id).to_upper(), str(objective_id).to_upper()]
	if _has_key(specific):
		return tr(specific)
	var generic := "OBJ_%s" % str(objective_id).to_upper()
	if _has_key(generic):
		return tr(generic)
	var literal := str(od.get("description", ""))
	if literal != "":
		return tr(literal) if _is_key_shaped(literal) and _has_key(literal) else literal
	return str(objective_id).capitalize()


## The quest title: its title_key -> QUEST_<ID>_TITLE -> the Lua `title` -> the readable id. Never a raw key.
func get_title(quest_id: Variant) -> String:
	var def := get_quest_def(StringName(str(quest_id)))
	var title_key := str(def.get("title_key", ""))
	if title_key != "" and _has_key(title_key):
		return tr(title_key)
	var derived := "QUEST_%s_TITLE" % str(quest_id).to_upper()
	if _has_key(derived):
		return tr(derived)
	var literal := str(def.get("title", ""))
	return literal if literal != "" else str(quest_id).capitalize()


## True while an ACTIVE quest still needs the item: a have objective that is open, the `needs` of an open objective (a delivery or a quest_spot
## cost) or an ingredient of a recipe an open recipe_crafted objective asks for. S-gifts hides such items from the gift picker.
func item_in_use(item_id: Variant) -> bool:
	var item := str(item_id)
	if item == "":
		return false
	for quest_id in active_quests:
		var rt: QuestRuntime = active_quests[quest_id]
		var defs := _objective_defs(quest_id)
		for objective_id in rt.objectives:
			if bool((rt.objectives[objective_id] as Dictionary).get("done", false)):
				continue
			var od: Dictionary = defs.get(str(objective_id), {})
			if bool(od.get("have", false)) and str(od.get("item", "")) == item:
				return true
			if _needs_of(od).has(item):
				return true
			if str(od.get("on", "")) == "recipe_crafted":
				var runtime := get_node_or_null("/root/LuaRuntime")
				var recipe: Variant = runtime.call("get_recipe", str(od.get("recipe", ""))) if runtime != null else {}
				if _Data.int_map(_Data.dict(recipe).get("ingredients", {})).has(item):
					return true
	return false


# =============================================================================================== save

func to_dict() -> Dictionary:
	var active := {}
	for qid in active_quests:
		active[qid] = (active_quests[qid] as QuestRuntime).to_dict()
	return {
		"v": SECTION_VERSION,
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
		if record.has("order") and not _valid_count(record["order"]):
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
			if objective.has("seen"):
				if not (objective["seen"] is Array):
					return false
				for npc in objective["seen"]:
					if not _valid_id(npc):
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
	var next_order := 0
	for qid in active:
		var runtime := QuestRuntime.from_dict(active[qid])
		restored[qid] = runtime
		next_order = maxi(next_order, runtime.order + 1)
	for qid in restored:                      # a save of before the acceptance order existed: the saved order of the records is the order
		var legacy: QuestRuntime = restored[qid]
		if legacy.order < 0:
			legacy.order = next_order
			next_order += 1
	_accept_counter = next_order
	active_quests = restored
	completed_quests = SaveCodec.names_from_json(data.get("completed", []))
	failed_quests = SaveCodec.names_from_json(data.get("failed", []))
	offered_quests = SaveCodec.names_from_json(data.get("offered", []))
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
	_refresh_queued = false
	return true


# =============================================================================================== small helpers

## {item: amount} an objective needs (a delivery or the cost of its quest_spot), ints, {} when it names none.
func _needs_of(od: Dictionary) -> Dictionary:
	return _Data.int_map(od.get("needs", {}))


func _has_key(key: String) -> bool:
	return str(TranslationServer.translate(key)) != key


static func _is_key_shaped(text: String) -> bool:
	var rx := RegEx.new()
	rx.compile("^[A-Z0-9_]+$")
	return rx.search(text) != null


static func _is_id(text: String) -> bool:
	var rx := RegEx.new()
	rx.compile("^[a-z][a-z0-9_]*$")
	return rx.search(text) != null


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


## "a, b,c" -> ["a", "b", "c"] (a single value gives one entry, "" none).
static func _csv(value: Variant) -> Array[String]:
	var out: Array[String] = []
	for part in str(value).split(",", false):
		var trimmed := part.strip_edges()
		if trimmed != "":
			out.append(trimmed)
	return out


## The filter value (a single value or a comma list) names `actual`; an empty filter matches anything.
static func _csv_contains(filter_value: Variant, actual: String) -> bool:
	var wanted := _csv(filter_value)
	return wanted.is_empty() or actual in wanted


## Payload entries compare as numbers when both are numbers (JSON gives 5.0 for 5), otherwise as text.
static func _same_value(a: Variant, b: Variant) -> bool:
	if _is_number(a) and _is_number(b):
		return is_equal_approx(float(a), float(b))
	return str(a) == str(b)
