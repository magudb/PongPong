class_name LifeFlow
extends RefCounted
## Small service dialogues share the production modal, portraits and quest actions.
static func screen(tree: SceneTree) -> Node:
	return tree.get_first_node_in_group("dialogue_ui")

static func ask(owner_node: Node, npc: String, lines: Array, choices: Array = []) -> Dictionary:
	if not is_instance_valid(owner_node) or not owner_node.is_inside_tree():
		return {}
	var ui := screen(owner_node.get_tree())
	if ui == null:
		return {}
	EventBus.dialogue_started.emit(StringName(npc), StringName(npc))
	var result: Dictionary = await ui.show_lines({"id": npc, "name_key": str(LuaRuntime.get_npc(npc).get("name_key", "NPC_" + npc.to_upper()))}, lines, choices)
	EventBus.dialogue_ended.emit()
	return result

static func offer(owner_node: Node, row: Dictionary) -> void:
	var id := StringName(str(row.get("quest_id", "")))
	if not QuestManager.is_offerable(id):
		return
	var result := await ask(owner_node, str(row.get("giver", "merchant_pip")), [{"text_key": "QUEST_%s_OFFER" % str(id).to_upper()}], [
		{"text_key": "LIFE_ACCEPT", "action": "quest_accept", "quest_id": str(id)}, {"text_key": "LIFE_LATER", "action": "close"}])
	var choice := LuaData.dict(result.get("choice", {}))
	if is_instance_valid(owner_node) and owner_node.is_inside_tree() and str(choice.get("action", "")) == "quest_accept" and QuestManager.is_offerable(id):
		QuestManager.accept_quest(id)

static func offers(kind: String) -> Array[Dictionary]:
	return QuestManager.offerable_for(LuaData.arr(GameManager.config_value("traetoppen." + kind + ".givers", ["mayor_lyra", "baker_maja", "merchant_pip", "farmer_rosa", "fairy_lily", "smith_thorin"])))
