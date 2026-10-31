class_name TutorialRunner
extends RefCounted
## The opening is data. A RefCounted session survives disposal long enough to
## finish cancellation; no awaited actor member outlives its scene.
class SkipGate extends Node:
	var session: RefCounted
	func _input(event: InputEvent) -> void:
		if session.active and event.is_pressed() and not event.is_echo() and event.is_action_pressed(&"ui_cancel"):
			session.skip()
			get_viewport().set_input_as_handled()

var origin: Dictionary = {}
var world: Node
var actors: Dictionary = {}
var active := false
var skipped := false
var gate: Node
var trace: Array[String] = []
var _area_ref: WeakRef
var _screen_ref: WeakRef
var _request: RefCounted

static func run(target: Node, retained: Dictionary = {}) -> bool:
	if retained.is_empty(): retained = EventBus.interaction_origin(&"p0")
	if retained.get("recipient", {}).get("player_id") != &"p0": return false
	if not EventBus.interaction_current(retained): return false
	if not bool(GameManager.config_value("farm_tutorial.first_morning.enabled", true)):
		return false
	if bool(GameManager.get_flag(&"first_morning_done", false)):
		return true
	var session := TutorialRunner.new()
	session.origin = retained
	session.world = target
	return await session.play()

func _good() -> bool:
	return EventBus.interaction_current(origin) and is_instance_valid(world) and world.is_inside_tree() and PlayerRegistry.world() == world and (_area_ref == null or _area_ref.get_ref() == world.area)

func skip() -> void:
	skipped = true
	var screen: Variant = _screen_ref.get_ref() if _screen_ref != null else null
	if is_instance_valid(screen) and _request != null:
		screen.close_request(_request)

func play() -> bool:
	if not _good() or str(world.area.map.id) != "farm":
		return false
	_area_ref = weakref(world.area)
	active = true
	var hour := float(GameManager.config_value("farm_tutorial.first_morning.hour", 6))
	TimeManager.set_weather(&"klart")
	if not _good():
		active = false
		return true
	GameManager.set_clock(int(hour), int(round(fmod(hour, 1) * 60)))
	if not _good():
		active = false
		return true
	gate = SkipGate.new()
	gate.session = self
	gate.name = "FirstMorningInput"
	world.add_child(gate)
	if not _good():
		active = false
		gate.queue_free()
		return true
	var steps := LuaData.arr(GameManager.config_value("farm_tutorial.first_morning.steps", []))
	for step in steps:
		if skipped or not _good():
			break
		trace.append(str(step.kind))
		EventBus.game_event.emit(&"tutorial_step", {"kind": str(step.kind), "id": str(step.get("id", step.get("npc", step.get("quest", ""))))})
		if not _good() or skipped: break
		match str(step.kind):
			"npc_enter":
				_enter(str(step.npc), str(step.post))
				if _good() and not skipped and DisplayServer.get_name() != "headless" and is_instance_valid(actors.get(str(step.npc))):
					# Own and await every request; Escape cancels the sequence after
					# the current warm finishes, without abandoning threaded sheets.
					var hold := StringName("tutorial_setup_%s" % get_instance_id())
					GameManager.push_modal(hold, false)
					if _good() and not skipped and is_instance_valid(actors.get(str(step.npc))):
						await actors[str(step.npc)].visual.warm_clips(["idle", "talk", "walk"])
					GameManager.pop_modal(hold)
			"dialogue":
				if str(step.get("context", "")) == "intro":
					await preload("res://scripts/world2d/intro_sequence.gd").letter(world, origin)
				else:
					await _dialogue(str(step.get("id", "")), str(step.get("npc", "postman_pip")))
			"npc_leave":
				await _leave(str(step.npc), str(step.get("to", "warp")))
			"quest_accept":
				QuestManager.accept_quest_owned(StringName(str(step.quest)), origin)
			"hint":
				EventBus.game_event.emit(&"tutorial_hint_request", {"id": str(step.id)})
			"wait":
				var left := maxf(0, float(step.get("seconds", 0)))
				while _good() and not skipped and left > 0:
					await world.get_tree().physics_frame
					left -= 1.0 / float(Engine.physics_ticks_per_second)
	active = false
	# Skip still delivers every accepted quest in this extensible sequence.
	if _good():
		for step in steps:
			if not _good(): break
			if str(step.kind) == "quest_accept":
				QuestManager.accept_quest_owned(StringName(str(step.quest)), origin)
		if skipped:
			for step in steps:
				if not _good(): break
				if str(step.kind) == "hint":
					EventBus.game_event.emit(&"tutorial_hint_request", {"id": str(step.id)})
		if EventBus.interaction_current(origin): GameManager.set_flag(&"intro_letter_seen", true)
		if EventBus.interaction_current(origin): GameManager.set_flag(&"first_morning_done", true)
		if EventBus.interaction_current(origin): EventBus.game_event.emit(&"tutorial_finished", {"skipped": skipped})
	for actor in actors.values():
		if is_instance_valid(actor):
			actor.queue_free()
	actors.clear()
	if is_instance_valid(gate):
		gate.queue_free()
	return true

func _enter(id: String, post: String) -> void:
	if not _good() or skipped: return
	var point: Vector2 = NpcDirector.post_ground(str(world.area.map.id), StringName(post))
	if point == Vector2.INF:
		for marker in world.area.find_markers("post"):
			if str(marker.params.get("name", "")) == post:
				point = Iso.to_ground(world.area.to_local(world.area.cell_to_global(marker.cell)))
	if point == Vector2.INF:
		return
	var actor := Npc2D.create({"id": id, "wander": "0", "guest": true})
	actor.area = world.area
	actor.position = Iso.to_screen(point)
	actors[id] = actor
	world.area.objects.add_child(actor)
	if not _actor_current(id, actor): return
	actor.event_begin()
	if not _actor_current(id, actor): return
	actor.face("SW")

func _actor_current(id: String, actor: Variant) -> bool:
	return _good() and is_instance_valid(actor) and actor.is_inside_tree() and not actor.is_queued_for_deletion() and actors.get(id) == actor and actor.area == world.area

func _dialogue(module: String, npc: String) -> void:
	if not _good():
		return
	var actor: Variant = actors.get(npc)
	if not _actor_current(npc, actor) or not is_instance_valid(world.player): return
	var owned := EventBus.interaction_attach(origin, actor, world.player)
	if owned.is_empty(): return
	var body_ref: WeakRef = weakref(world.player)
	var ctx: Dictionary = PlayerRegistry.for_player(origin.recipient.player_id, func(): return NpcDialogue.context(npc, body_ref.get_ref()))
	if not _actor_current(npc, actor) or not EventBus.interaction_body_current(owned, actor, body_ref.get_ref()): return
	var page: Dictionary = PlayerRegistry.for_player(origin.recipient.player_id, func(): return LuaRuntime.get_dialogue(module, ctx))
	if not _actor_current(npc, actor) or not EventBus.interaction_body_current(owned, actor, body_ref.get_ref()) or page.is_empty():
		return
	page["social"] = false
	page = Svc.static_call("res://scripts/reactions/race_reactions.gd", &"apply", [npc, ctx, page], page)
	if not _actor_current(npc, actor) or not EventBus.interaction_body_current(owned, actor, body_ref.get_ref()): return
	var screen: Node = world.get_tree().get_first_node_in_group("dialogue_ui")
	if screen == null:
		return
	_screen_ref = weakref(screen)
	actor.dialogue_id = StringName(module)
	var request: RefCounted = actor._begin_followup(body_ref.get_ref(), page, owned)
	_request = request
	if skipped and is_instance_valid(screen) and request != null: screen.close_request(request)
	if request == null:
		skipped = true
		return
	var result: Dictionary = await screen.wait_request(request)
	if _request == request: _request = null
	if not bool(result.get("completed", false)):
		skipped = true
	# Let the actor's normal completion release the player before the next page.
	if _good():
		await world.get_tree().process_frame

func _leave(npc: String, destination: String) -> void:
	var actor: Npc2D = actors.get(npc)
	if actor == null or not is_instance_valid(actor) or not _good():
		return
	var point: Vector2 = world.area.get_spawn("from_traetoppen")
	if destination != "warp":
		var ground := NpcDirector.post_ground(str(world.area.map.id), StringName(destination))
		if ground != Vector2.INF:
			point = world.area.to_global(Iso.to_screen(ground))
	var path := PackedVector2Array()
	for director in world.get_tree().get_nodes_in_group("town_director"):
		if director.area == world.area and director.nav != null:
			path = director.nav.path(world.area.global_to_cell(actor.global_position), world.area.global_to_cell(point)).get("polyline", PackedVector2Array())
			break
	if path.is_empty():
		path.append(point)
	actor._interact.collision_layer = 0
	for waypoint in path:
		if not _good() or not is_instance_valid(actor) or skipped:
			break
		actor.event_walk_to(waypoint, 285)
		while _good() and is_instance_valid(actor) and actor._event_walking and not skipped:
			await world.get_tree().physics_frame
	if is_instance_valid(actor) and actors.get(npc) == actor:
		actor.queue_free()
		actors.erase(npc)
