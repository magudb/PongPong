extends RefCounted
## A new-game hook, never a load hook. The first-morning runner owns its extended farm staging.
static func run(world: Node) -> void:
	if bool(GameManager.get_flag(&"intro_letter_seen", false)):
		return
	if bool(await Svc.static_call("res://scripts/farm/steading/tutorial/tutorial_runner.gd", &"run", [world], false)):
		return
	await letter(world)
	QuestManager.accept_quest(&"intro_lottery")

static func letter(world: Node) -> void:
	var screen := world.get_tree().get_first_node_in_group("dialogue_ui")
	if screen == null or bool(GameManager.get_flag(&"intro_letter_seen", false)):
		return
	var ctx := NpcDialogue.context("fairy_king", world.get("player"))
	ctx["intro"] = true
	var page := LuaRuntime.get_dialogue("fairy_king", ctx)
	EventBus.dialogue_started.emit(&"fairy_king", &"fairy_king")
	var result: Dictionary = await screen.show_lines({"id": "fairy_king", "name_key": "NPC_FAIRY_KING"}, LuaData.arr(page.get("lines", [])), [])
	var reaction: Dictionary = Svc.static_call("res://scripts/reactions/race_reactions.gd", &"line_for", ["fairy_king", "intro", ctx], {})
	if bool(result.get("completed", false)) and not reaction.is_empty() and world.is_inside_tree():
		await screen.show_lines({"id": "fairy_king", "name_key": "NPC_FAIRY_KING"}, [reaction], [])
	GameManager.set_flag(&"intro_letter_seen", true)
	EventBus.dialogue_ended.emit()
