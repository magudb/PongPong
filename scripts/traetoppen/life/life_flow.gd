class_name LifeFlow
extends RefCounted
## Small service dialogues share the production modal, portraits and quest actions.
static func screen(tree: SceneTree) -> Node:
	return tree.get_first_node_in_group("dialogue_ui")

## Physical service roots never borrow the ambient player or create a profile.
## The extra weak area observation is lexical; EventBus still owns model checks.
static func service_origin(owner: Variant, body: Variant) -> Dictionary:
	if not is_instance_valid(owner) or not is_instance_valid(body) or not body is Node: return {}
	var id := PlayerRegistry.registered_id(body)
	if id == &"": return {}
	var world := PlayerRegistry.world()
	if world == null or not is_instance_valid(world.area) or not world.area.is_ancestor_of(owner): return {}
	var origin := EventBus.interaction_origin(id, owner, body)
	if not EventBus.interaction_body_current(origin, owner, body): return {}
	var retained := origin.duplicate()
	retained["service_area"] = weakref(world.area)
	retained.make_read_only()
	return retained

static func current(origin: Dictionary, owner: Variant) -> bool:
	if not EventBus.interaction_current(origin) or not is_instance_valid(owner) or not owner is Node or not owner.is_inside_tree() or owner.is_queued_for_deletion(): return false
	if not origin.has("service_area"): return true # trusted nonphysical root
	var world := PlayerRegistry.world()
	var area: Variant = origin.service_area.get_ref()
	var body: Variant = origin.physical.body.get_ref()
	return is_instance_valid(area) and world != null and world.area == area and area.is_ancestor_of(owner) and EventBus.interaction_body_current(origin, owner, body)

static func ask(owner_node: Node, npc: String, lines: Array, choices: Array = [], origin: Dictionary = {}) -> Dictionary:
	if origin.is_empty(): origin = EventBus.interaction_origin()
	if not current(origin, owner_node): return {}
	var ui := screen(owner_node.get_tree())
	if ui == null: return {}
	var ui_ref: WeakRef = weakref(ui)
	var owner_ref: WeakRef = weakref(owner_node)
	var request: RefCounted = ui.create_request()
	var previous: RefCounted = ui._request
	var previous_generation: int = ui._generation
	var attachment := RefCounted.new()
	var name_key := str(LuaRuntime.get_npc(npc).get("name_key", "NPC_" + npc.to_upper()))
	if not current(origin, owner_ref.get_ref()): return {}
	EventBus.publish_dialogue_started(origin, StringName(npc), StringName(npc), attachment)
	if not current(origin, owner_ref.get_ref()) or not is_instance_valid(ui_ref.get_ref()) or not ui.is_inside_tree() or ui._request != previous or ui._generation != previous_generation:
		EventBus.publish_dialogue_ended(origin, attachment)
		return {}
	ui.request_lines({"id": npc, "name_key": name_key}, lines, choices, request)
	var result: Dictionary = await ui.wait_request(request)
	EventBus.publish_dialogue_ended(origin, attachment)
	return result if current(origin, owner_ref.get_ref()) else {}

static func offer(owner_node: Node, row: Dictionary, origin: Dictionary = {}) -> void:
	if origin.is_empty(): origin = EventBus.interaction_origin()
	if not current(origin, owner_node): return
	var id := StringName(str(row.get("quest_id", "")))
	if not QuestManager.is_offerable_owned(id, origin) or not current(origin, owner_node): return
	var owner_ref: WeakRef = weakref(owner_node)
	var result := await ask(owner_node, str(row.get("giver", "merchant_pip")), [{"text_key": "QUEST_%s_OFFER" % str(id).to_upper()}], [
		{"text_key": "LIFE_ACCEPT", "action": "quest_accept", "quest_id": str(id)}, {"text_key": "LIFE_LATER", "action": "close"}], origin)
	if not current(origin, owner_ref.get_ref()): return
	var choice := LuaData.dict(result.get("choice", {}))
	if str(choice.get("action", "")) == "quest_accept" and QuestManager.is_offerable_owned(id, origin) and current(origin, owner_ref.get_ref()):
		QuestManager.accept_quest_owned(id, origin)

static func offers(kind: String, origin: Dictionary = {}) -> Array[Dictionary]:
	if origin.is_empty(): origin = EventBus.interaction_origin()
	if not EventBus.interaction_current(origin): return []
	return QuestManager.offerable_for_owned(LuaData.arr(GameManager.config_value("traetoppen." + kind + ".givers", ["mayor_lyra", "baker_maja", "merchant_pip", "farmer_rosa", "fairy_lily", "smith_thorin"])), origin)
