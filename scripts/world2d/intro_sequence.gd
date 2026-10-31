extends RefCounted
## A new-game host hook, never a load hook. Earned page effects outlive the body;
## optional presentation retains the original weak scene/area/body/UI request.
static func run(world: Node) -> void:
	var origin := EventBus.interaction_origin(&"p0")
	if not _root(world, origin) or bool(GameManager.get_flag(&"intro_letter_seen", false)): return
	if bool(await Svc.static_await("res://scripts/farm/steading/tutorial/tutorial_runner.gd", &"run", [world, origin], false)): return
	if not _root(world, origin): return
	await letter(world, origin)
	if EventBus.interaction_current(origin): QuestManager.accept_quest_owned(&"intro_lottery", origin)

static func _root(world: Variant, origin: Dictionary) -> bool:
	return origin.get("recipient", {}).get("player_id") == &"p0" and EventBus.interaction_current(origin) and is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion() and world == PlayerRegistry.world()

static func _present(origin: Dictionary, physical: Dictionary, world_ref: WeakRef, area_ref: WeakRef, ui_ref: WeakRef, body_ref: WeakRef) -> bool:
	var world: Variant = world_ref.get_ref()
	var ui: Variant = ui_ref.get_ref()
	var area: Variant = area_ref.get_ref()
	return _root(world, origin) and is_instance_valid(area) and world.area == area and area.is_inside_tree() and is_instance_valid(ui) and ui.is_inside_tree() and not ui.is_queued_for_deletion() and EventBus.interaction_body_current(physical, world, body_ref.get_ref())

static func letter(world: Node, origin: Dictionary = {}, tutorial: RefCounted = null) -> void:
	if origin.is_empty(): origin = EventBus.interaction_origin(&"p0")
	if not _root(world, origin) or bool(GameManager.get_flag(&"intro_letter_seen", false)): return
	var ui: Node = world.get_tree().get_first_node_in_group("dialogue_ui")
	var body: Variant = world.get("player")
	if ui == null or not is_instance_valid(body) or PlayerRegistry.registered_id(body) != &"p0": return
	var physical := EventBus.interaction_attach(origin, world, body)
	var world_ref: WeakRef = weakref(world)
	var area_ref: WeakRef = weakref(world.area)
	var ui_ref: WeakRef = weakref(ui)
	var body_ref: WeakRef = weakref(body)
	var request: RefCounted = ui.create_request()
	var previous: RefCounted = ui._request
	var previous_generation: int = ui._generation
	var ctx: Dictionary = PlayerRegistry.for_player(&"p0", func(): return NpcDialogue.context("fairy_king", body_ref.get_ref()))
	if not _present(origin, physical, world_ref, area_ref, ui_ref, body_ref): return
	ctx["intro"] = true
	var page: Dictionary = PlayerRegistry.for_player(&"p0", func(): return LuaRuntime.get_dialogue("fairy_king", ctx))
	if not _present(origin, physical, world_ref, area_ref, ui_ref, body_ref): return
	var attachment := RefCounted.new()
	EventBus.publish_dialogue_started(origin, &"fairy_king", &"fairy_king", attachment)
	if not _present(origin, physical, world_ref, area_ref, ui_ref, body_ref) or ui._request != previous or ui._generation != previous_generation:
		EventBus.publish_dialogue_ended(origin, attachment)
		return
	if tutorial != null:
		tutorial._screen_ref = ui_ref
		tutorial._request = request
	var generation: int = ui._generation + 1
	ui.request_lines({"id": "fairy_king", "name_key": "NPC_FAIRY_KING"}, LuaData.arr(page.get("lines", [])), [], request)
	if tutorial != null and tutorial.skipped: ui.close_request(request)
	var result: Dictionary = await ui.wait_request(request)
	if tutorial != null and tutorial._request == request: tutorial._request = null
	if _present(origin, physical, world_ref, area_ref, ui_ref, body_ref) and bool(result.get("completed", false)) and ui._generation == generation and ui._request == null:
		var reaction: Dictionary = PlayerRegistry.for_player(&"p0", func(): return Svc.static_call("res://scripts/reactions/race_reactions.gd", &"line_for", ["fairy_king", "intro", ctx], {}))
		if _present(origin, physical, world_ref, area_ref, ui_ref, body_ref) and ui._generation == generation and ui._request == null and not reaction.is_empty() and (tutorial == null or not tutorial.skipped):
			request = ui.create_request()
			if tutorial != null: tutorial._request = request
			ui.request_lines({"id": "fairy_king", "name_key": "NPC_FAIRY_KING"}, [reaction], [], request)
			await ui.wait_request(request)
			if tutorial != null and tutorial._request == request: tutorial._request = null
	# Preserve legacy Escape/seen behaviour and essential already-read effects,
	# but never borrow winner authority or require the optional departed body.
	if EventBus.interaction_current(origin): GameManager.set_flag(&"intro_letter_seen", true)
	EventBus.publish_dialogue_ended(origin, attachment)
