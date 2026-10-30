extends RefCounted
## A new-game hook, never a load hook. The first-morning runner owns its extended farm staging.
static func run(world: Node) -> void:
	var origin := EventBus.interaction_origin()
	if origin.is_empty(): return
	if bool(GameManager.get_flag(&"intro_letter_seen", false)):
		return
	if bool(await Svc.static_await("res://scripts/farm/steading/tutorial/tutorial_runner.gd", &"run", [world, origin], false)):
		return
	if not EventBus.interaction_current(origin): return
	await letter(world, origin)
	if EventBus.interaction_current(origin) and is_instance_valid(world) and world.is_inside_tree():
		QuestManager.accept_quest(&"intro_lottery")

static func letter(world: Node, origin: Dictionary = {}) -> void:
	if origin.is_empty(): origin = EventBus.interaction_origin()
	if not EventBus.interaction_current(origin) or not is_instance_valid(world) or not world.is_inside_tree(): return
	var screen := world.get_tree().get_first_node_in_group("dialogue_ui")
	if screen == null or bool(GameManager.get_flag(&"intro_letter_seen", false)):
		return
	var ctx := NpcDialogue.context("fairy_king", world.get("player"))
	if not EventBus.interaction_current(origin): return
	ctx["intro"] = true
	var page := LuaRuntime.get_dialogue("fairy_king", ctx)
	if not EventBus.interaction_current(origin): return
	var attachment := RefCounted.new()
	EventBus.publish_dialogue_started(origin, &"fairy_king", &"fairy_king", attachment)
	if not EventBus.interaction_current(origin):
		EventBus.publish_dialogue_ended(origin, attachment)
		return
	var request: RefCounted = screen.create_request()
	screen.request_lines({"id": "fairy_king", "name_key": "NPC_FAIRY_KING"}, LuaData.arr(page.get("lines", [])), [], request)
	var result: Dictionary = await screen.wait_request(request)
	if not EventBus.interaction_current(origin):
		EventBus.publish_dialogue_ended(origin, attachment)
		return
	var reaction: Dictionary = Svc.static_call("res://scripts/reactions/race_reactions.gd", &"line_for", ["fairy_king", "intro", ctx], {})
	if EventBus.interaction_current(origin) and bool(result.get("completed", false)) and not reaction.is_empty() and is_instance_valid(world) and world.is_inside_tree():
		request = screen.create_request()
		screen.request_lines({"id": "fairy_king", "name_key": "NPC_FAIRY_KING"}, [reaction], [], request)
		await screen.wait_request(request)
	if EventBus.interaction_current(origin) and is_instance_valid(world) and world.is_inside_tree():
		GameManager.set_flag(&"intro_letter_seen", true)
	EventBus.publish_dialogue_ended(origin, attachment)
