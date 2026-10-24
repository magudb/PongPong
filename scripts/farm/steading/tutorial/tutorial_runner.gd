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

var world: Node
var actors: Dictionary = {}
var active := false
var skipped := false
var gate: Node
var trace: Array[String] = []

static func run(target: Node) -> bool:
	if not bool(GameManager.config_value("farm_tutorial.first_morning.enabled", true)):
		return false
	if bool(GameManager.get_flag(&"first_morning_done", false)):
		return true
	var session := TutorialRunner.new()
	session.world = target
	return await session.play()

func _good() -> bool:
	return is_instance_valid(world) and world.is_inside_tree()

func skip() -> void:
	skipped = true
	if _good():
		var screen := world.get_tree().get_first_node_in_group("dialogue_ui")
		if screen != null and screen.is_open():
			screen.close()

func play() -> bool:
	if not _good() or str(world.area.map.id) != "farm":
		return false
	active = true
	var hour := float(GameManager.config_value("farm_tutorial.first_morning.hour", 6))
	TimeManager.set_weather(&"klart")
	GameManager.set_clock(int(hour), int(round(fmod(hour, 1) * 60)))
	gate = SkipGate.new()
	gate.session = self
	gate.name = "FirstMorningInput"
	world.add_child(gate)
	var steps := LuaData.arr(GameManager.config_value("farm_tutorial.first_morning.steps", []))
	for step in steps:
		if skipped or not _good():
			break
		trace.append(str(step.kind))
		EventBus.game_event.emit(&"tutorial_step", {"kind": str(step.kind), "id": str(step.get("id", step.get("npc", step.get("quest", ""))))})
		match str(step.kind):
			"npc_enter":
				_enter(str(step.npc), str(step.post))
				if DisplayServer.get_name() != "headless" and actors.has(str(step.npc)):
					# Own and await every request; Escape cancels the sequence after
					# the current warm finishes, without abandoning threaded sheets.
					GameManager.push_modal(&"tutorial_setup", false)
					await actors[str(step.npc)].visual.warm_clips(["idle", "talk", "walk"])
					GameManager.pop_modal(&"tutorial_setup")
			"dialogue":
				if str(step.get("context", "")) == "intro":
					await preload("res://scripts/world2d/intro_sequence.gd").letter(world)
				else:
					await _dialogue(str(step.get("id", "")), str(step.get("npc", "postman_pip")))
			"npc_leave":
				await _leave(str(step.npc), str(step.get("to", "warp")))
			"quest_accept":
				QuestManager.accept_quest(StringName(str(step.quest)))
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
			if str(step.kind) == "quest_accept":
				QuestManager.accept_quest(StringName(str(step.quest)))
		if skipped:
			for step in steps:
				if str(step.kind) == "hint":
					EventBus.game_event.emit(&"tutorial_hint_request", {"id": str(step.id)})
		GameManager.set_flag(&"intro_letter_seen", true)
		GameManager.set_flag(&"first_morning_done", true)
		EventBus.game_event.emit(&"tutorial_finished", {"skipped": skipped})
	for actor in actors.values():
		if is_instance_valid(actor):
			actor.queue_free()
	actors.clear()
	if is_instance_valid(gate):
		gate.queue_free()
	return true

func _enter(id: String, post: String) -> void:
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
	world.area.objects.add_child(actor)
	actor.event_begin()
	actor.face("SW")
	actors[id] = actor

func _dialogue(module: String, npc: String) -> void:
	if not _good():
		return
	var actor: Npc2D = actors.get(npc)
	var ctx := NpcDialogue.context(npc, world.player)
	var page := LuaRuntime.get_dialogue(module, ctx)
	if actor == null or page.is_empty():
		return
	page["social"] = false
	page = Svc.static_call("res://scripts/reactions/race_reactions.gd", &"apply", [npc, ctx, page], page)
	var screen: Node = world.get_tree().get_first_node_in_group("dialogue_ui")
	if screen == null:
		return
	actor.dialogue_id = StringName(module)
	actor._begin_followup(world.player, page)
	if not actor.is_talking or not screen.is_open():
		skipped = true
		return
	var result: Dictionary = await screen.session_finished
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
	if is_instance_valid(actor):
		actor.queue_free()
	actors.erase(npc)
