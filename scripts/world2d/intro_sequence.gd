extends RefCounted
## A new-game hook, never a load hook. Every page retains the opening root.
const Origin := preload("res://scripts/traetoppen/life/presenter_origin.gd")
static func run(world: Node) -> void:
	var origin: RefCounted = Origin.capture(world)
	if origin == null or bool(GameManager.get_flag(&"intro_letter_seen", false)): return
	if bool(await Svc.static_await("res://scripts/farm/steading/tutorial/tutorial_runner.gd", &"run", [world], false)): return
	if not origin.current(): return
	await letter(origin.world.get_ref(), origin, func(): QuestManager.accept_quest(&"intro_lottery"))

static func letter(world: Node, origin: RefCounted = null, after: Callable = Callable(), claimed: Callable = Callable()) -> void:
	if origin == null: origin = Origin.capture(world)
	if origin == null or not origin.current(): return
	var ui: Node = LifeFlow.screen(world.get_tree())
	if ui == null or bool(GameManager.get_flag(&"intro_letter_seen", false)): return
	var ctx: Dictionary = origin.call_owned(func(): return NpcDialogue.context("fairy_king", origin.body.get_ref()))
	ctx["intro"] = true
	var page := LuaRuntime.get_dialogue("fairy_king", ctx)
	var reaction: Dictionary = Svc.static_call("res://scripts/reactions/race_reactions.gd", &"line_for", ["fairy_king", "intro", ctx], {})
	var ui_ref: WeakRef = weakref(ui)
	var following: Array = []
	var retained := origin
	var speaker := {"id":"fairy_king", "name_key":"NPC_FAIRY_KING"}
	var ticket: RefCounted = origin.page(world, ui, speaker, LuaData.arr(page.get("lines", [])), [], {
		"events":true, "module":"fairy_king", "prepare":func(receipt):
			if claimed.is_valid(): claimed.call(receipt)
			return {},
		"after":func(receipt, result):
			var screen: Variant = ui_ref.get_ref()
			if not Origin._live(screen) or not retained.current(false) or not screen.completion_effects_current(receipt): return
			if bool(result.get("completed", false)) and not reaction.is_empty() and retained.current() and screen.optional_allowed(receipt):
				following.append(retained.page(null, screen, speaker, [reaction], [], {"prepare":func(next):
					if claimed.is_valid(): claimed.call(next)
					return {},
					"after":func(next, _result): _finish(retained, ui_ref, next, after)}))
			else: _finish(retained, ui_ref, receipt, after)})
	if ticket != null: await ticket.wait()
	if not following.is_empty() and following[0] != null: await following[0].wait()

static func _finish(origin: RefCounted, ui_ref: WeakRef, ticket: RefCounted, after: Callable) -> void:
	var ui: Variant = ui_ref.get_ref()
	if not Origin._live(ui) or not origin.current(false) or not ui.completion_effects_current(ticket): return
	# Escape deliberately acknowledges the authored opening, as did the old hook.
	GameManager.set_flag(&"intro_letter_seen", true)
	if origin.current() and ui.optional_allowed(ticket) and after.is_valid(): origin.call_owned(after)
