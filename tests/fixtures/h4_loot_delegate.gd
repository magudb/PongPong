extends RefCounted
## Supported LootService delegate installation, not a replacement pure reader.
static func _static_init() -> void:
	_hook("bind")
static func _hook(seam: String) -> void:
	var callback: Callable = Engine.get_meta("h4_delegate_hook", Callable())
	if callback.is_valid(): callback.call(seam)

static func roll_container(_state: Dictionary, _req: Dictionary) -> Dictionary:
	_hook("plan")
	return {"ok":true,"results":[{"id":"wood","amount":2,"kind":"material","rarity":"normal"}]}

static func fits(_plan: Dictionary, _view: Dictionary) -> bool:
	_hook("fit")
	return true

static func commit(state: Dictionary, _plan: Dictionary) -> Dictionary:
	_hook("commit")
	state["h4_commits"] = int(state.get("h4_commits",0))+1
	return state
