extends RefCounted
static func attach(actor: Node) -> void:
	actor.set_meta("hook_calls", int(actor.get_meta("hook_calls", 0)) + 1)
