class_name LifeFlow
extends RefCounted
## Small service dialogues share the production modal, portraits and quest actions.
static func screen(tree: SceneTree) -> Node:
	return tree.get_first_node_in_group("dialogue_ui")

## Presentation receipts are not authority after wait(). Consequential work must
## run in the exact request's after callback while optional_allowed is available.
static func request(owner_node: Node, npc: String, lines: Array, choices: Array = [], body: Variant = null, after: Callable = Callable()) -> RefCounted:
	if not is_instance_valid(owner_node) or not owner_node.is_inside_tree(): return null
	var origin: RefCounted = preload("res://scripts/traetoppen/life/presenter_origin.gd").capture(owner_node, body)
	return request_owned(owner_node, npc, lines, choices, origin, after)

static func request_owned(owner_node: Node, npc: String, lines: Array, choices: Array, origin: RefCounted, after: Callable = Callable()) -> RefCounted:
	if origin == null or not origin.current() or not is_instance_valid(owner_node) or not owner_node.is_inside_tree(): return null
	var body: Variant = origin.body.get_ref()
	var ui := screen(owner_node.get_tree())
	if ui == null: return null
	if body == null: body = PlayerRegistry.local_player(owner_node.get_tree())
	if not is_instance_valid(body) or not body is Node or not body.is_inside_tree() or body.is_queued_for_deletion(): return null
	var pid := PlayerRegistry.registered_id(body)
	var model: Variant = PlayerRegistry._states.get(pid)
	if pid == &"" or model == null: return null
	var model_ref: WeakRef = weakref(model)
	var ui_ref: WeakRef = weakref(ui)
	var owner_ref: WeakRef = weakref(owner_node)
	var teardown: Array[Callable] = []
	return ui.request_page(owner_node, {"id": npc, "name_key": str(LuaRuntime.get_npc(npc).get("name_key", "NPC_" + npc.to_upper()))}, lines, choices, {
		"body": body, "events": true, "module": npc,
		"prepare": func(ticket):
			var owner: Variant = owner_ref.get_ref()
			var close_page := func():
				var current: Variant = ui_ref.get_ref()
				if is_instance_valid(current): current.close_owned(ticket)
			if is_instance_valid(owner) and owner is Node:
				teardown.append(close_page)
				owner.tree_exiting.connect(close_page, CONNECT_ONE_SHOT)
			return {},
		"settle": func(_ticket, _result):
			var owner: Variant = owner_ref.get_ref()
			if is_instance_valid(owner) and owner is Node and not teardown.is_empty() and owner.tree_exiting.is_connected(teardown[0]):
				owner.tree_exiting.disconnect(teardown[0])
			teardown.clear(),
		"after": func(ticket, result):
			var current: Variant = ui_ref.get_ref()
			if not is_instance_valid(current) or not current.optional_allowed(ticket): return
			if not origin.current() or model_ref.get_ref() == null or PlayerRegistry._states.get(pid) != model_ref.get_ref(): return
			if after.is_valid(): PlayerRegistry.for_player(pid, func(): after.call(ticket, result))})

static func ask(owner_node: Node, npc: String, lines: Array, choices: Array = [], body: Variant = null) -> Dictionary:
	var ticket := request(owner_node, npc, lines, choices, body)
	return await ticket.wait() if ticket != null else {}

static func offer_request(owner_node: Node, row: Dictionary, body: Variant = null) -> RefCounted:
	var origin: RefCounted = preload("res://scripts/traetoppen/life/presenter_origin.gd").capture(owner_node, body)
	if origin == null: return null
	return offer_request_owned(owner_node, row, origin)

static func offer_request_owned(owner_node: Node, row: Dictionary, origin: RefCounted) -> RefCounted:
	if origin == null or not origin.current(): return null
	var id := StringName(str(row.get("quest_id", "")))
	if not bool(origin.call_owned(func(): return QuestManager.is_offerable(id))): return null
	return request_owned(owner_node, str(row.get("giver", "merchant_pip")), [{"text_key": "QUEST_%s_OFFER" % str(id).to_upper()}], [
		{"text_key": "LIFE_ACCEPT", "action": "quest_accept", "quest_id": str(id)}, {"text_key": "LIFE_LATER", "action": "close"}], origin,
		func(_ticket, result):
			var choice := LuaData.dict(result.get("choice", {}))
			if bool(result.get("completed", false)) and str(choice.get("action", "")) == "quest_accept" and QuestManager.is_offerable(id):
				QuestManager.accept_quest_owned(id, origin.current))

static func offer(owner_node: Node, row: Dictionary, body: Variant = null) -> void:
	var ticket := offer_request(owner_node, row, body)
	if ticket != null: await ticket.wait()

static func offers(kind: String) -> Array[Dictionary]:
	return QuestManager.offerable_for(LuaData.arr(GameManager.config_value("traetoppen." + kind + ".givers", ["mayor_lyra", "baker_maja", "merchant_pip", "farmer_rosa", "fairy_lily", "smith_thorin"])))
