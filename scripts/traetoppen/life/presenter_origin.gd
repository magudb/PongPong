extends RefCounted
## Lexical producer origin. Never an ambient permit or a persistent player scope.
var pid: StringName
var profile: WeakRef
var body: WeakRef
var world: WeakRef
var run: RefCounted

static func capture(node: Node, player: Variant = null) -> RefCounted:
	if not _live(node): return null
	if player == null: player = PlayerRegistry.local_player(node.get_tree())
	if not _live(player): return null
	var id := PlayerRegistry.registered_id(player)
	var model: Variant = PlayerRegistry._states.get(id)
	var scene: Variant = node.get_tree().get_first_node_in_group("world_2d")
	if id == &"" or model == null or not _live(scene): return null
	var origin := new()
	origin.pid = id
	origin.profile = weakref(model)
	origin.body = weakref(player)
	origin.world = weakref(scene)
	origin.run = SocialManager._accounting_world
	return origin

static func _live(value: Variant) -> bool:
	return is_instance_valid(value) and value is Node and value.is_inside_tree() and not value.is_queued_for_deletion()

func current(physical := true) -> bool:
	if SocialManager._accounting_suspended or SocialManager._accounting_world != run: return false
	if profile.get_ref() == null or PlayerRegistry._states.get(pid) != profile.get_ref(): return false
	if not _live(world.get_ref()): return false
	if not physical: return true
	var player: Variant = body.get_ref()
	return _live(player) and PlayerRegistry.registered_id(player) == pid and PlayerRegistry.by_id(pid) == player

func call_owned(operation: Callable, physical := true) -> Variant:
	if not current(physical): return null
	return PlayerRegistry.for_player(pid, operation)

func page(owner: Variant, ui: Node, speaker: Dictionary, lines: Array, choices: Array = [], options: Dictionary = {}) -> RefCounted:
	if not current() or not _live(ui): return null
	var configured := options.duplicate()
	configured.body = body.get_ref()
	return ui.request_page(owner, speaker, lines, choices, configured)

func earned_page(owner: Variant, ui: Node, speaker: Dictionary, lines: Array, choices: Array, point: Vector2, effect: Callable) -> RefCounted:
	var ui_ref: WeakRef = weakref(ui)
	return page(owner, ui, speaker, lines, choices, {
		"started":func(receipt):
			var screen: Variant = ui_ref.get_ref()
			if _live(screen) and current(): screen.acquire_hold(receipt, point),
		"after":func(receipt, result):
			var screen: Variant = ui_ref.get_ref()
			if _live(screen) and current(false) and screen.completion_effects_current(receipt):
				var effects_current := func() -> bool:
					var live_screen: Variant = ui_ref.get_ref()
					return _live(live_screen) and current(false) and live_screen.completion_effects_current(receipt)
				call_owned(func(): effect.call(result, effects_current), false)})

## Independent model roots capture once before their first callback. Existing
## owned callers must forward their guard instead of using this adapter.
static func model_guard() -> Callable:
	var id := PlayerRegistry.acting_id()
	var model: Variant = PlayerRegistry._states.get(id)
	var model_ref: WeakRef = weakref(model) if model != null else null
	var identity: RefCounted = SocialManager._accounting_world
	return func() -> bool:
		return model_ref != null and model_ref.get_ref() != null and PlayerRegistry._states.get(id) == model_ref.get_ref() and PlayerRegistry.acting_id() == id and not SocialManager._accounting_suspended and SocialManager._accounting_world == identity
