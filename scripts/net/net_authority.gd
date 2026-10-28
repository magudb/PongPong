class_name NetAuthority
extends RefCounted
## Fail-closed role follows the guest World even after detach/transport loss.
## No caller-controlled permission flag or cross-await actor scope.
static var _guest_owner: WeakRef

static func bind_guest(world: Node) -> bool:
	var running := PlayerRegistry.world()
	if running != null and running != world: return false
	var old: Variant = _guest_owner.get_ref() if _guest_owner != null else null
	if is_instance_valid(old) and old != world: return false
	_guest_owner = weakref(world)
	return true

static func owns_guest(world: Node) -> bool:
	return _guest_owner != null and is_instance_valid(world) and _guest_owner.get_ref() == world

static func can_write() -> bool:
	var guest: Variant = _guest_owner.get_ref() if _guest_owner != null else null
	return not is_instance_valid(guest)

static func session() -> Node:
	var world := PlayerRegistry.world()
	return world.get("session") if world != null else null

static func owns_network_world() -> bool:
	if not can_write(): return true
	var current := session()
	return current != null and current.state not in [&"idle", &"ended"]
