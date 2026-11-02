extends RefCounted
## The gift is already committed. This root owns presentation, never another reward.
const Origin := preload("res://scripts/traetoppen/life/presenter_origin.gd")
static func run(npc: String, result: Dictionary, actor: WeakRef) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var world: Variant = PlayerRegistry.world(tree)
	if not Origin._live(world): return
	var origin: RefCounted = Origin.capture(world)
	if origin == null: return
	var citizen: Variant = actor.get_ref() if actor != null else null
	var generation: int = int(citizen.get("_talk_generation")) if Origin._live(citizen) and citizen is Npc2D else -1
	var special := bool(result.get("special", false))
	var line: Dictionary = {} if special else origin.call_owned(func(): return GiftFlow.react(npc, result, false))
	if not origin.current(): return
	var lines := RelationshipFlow.reaction_lines(npc, result) if special else [line]
	var ui: Node = LifeFlow.screen(tree)
	var staged := await RelationshipFlow.play_scene_owned(npc, result, actor, origin) if special else false
	if not origin.current(): return
	if not staged and ui != null and not lines.is_empty() and not lines[0].is_empty():
		var ui_ref: WeakRef = weakref(ui)
		var point: Vector2 = citizen.global_position if Origin._live(citizen) and citizen is Node2D else Vector2.ZERO
		var ticket: RefCounted = origin.page(null, ui, {"id":npc, "name_key":SocialData.npc_row(npc).get("name_key", "")}, lines, [], {
			"started":func(receipt):
				var screen: Variant = ui_ref.get_ref()
				if Origin._live(screen) and origin.current(): screen.acquire_hold(receipt, point),
			"settle":func(receipt, _terminal):
				var screen: Variant = ui_ref.get_ref()
				if Origin._live(screen) and origin.current() and screen.optional_allowed(receipt): _release(actor, generation)})
		if ticket != null: await ticket.wait()
	elif staged: _release(actor, generation)

static func _release(actor: WeakRef, generation: int) -> void:
	var citizen: Variant = actor.get_ref() if actor != null else null
	if Origin._live(citizen) and citizen is Npc2D and citizen._talk_generation == generation and not citizen.is_talking: citizen.hold(false)
