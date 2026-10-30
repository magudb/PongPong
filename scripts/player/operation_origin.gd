class_name OperationOrigin
extends RefCounted
## Pure comparison of caller-supplied, callback-free, noncreating observations.
## No service lookup, admission, mutation, serialization or ambient authority.
## Capture ONCE before callbacks; after callbacks compare that same origin with
## a fresh observation. Never replace an old origin with capture(current).
## Callers supply peek_state, _save_owner_stamp, role/write permission and
## continuation_available(profile); a false barrier result never latches here.

static func snapshot(player_id: StringName, profile: RefCounted, stamp: Array, role: StringName, writable: bool, available: bool) -> Dictionary:
	if not _stamp_valid(stamp): return _empty()
	var value_stamp := stamp.duplicate()
	value_stamp.make_read_only()
	var result := {"player_id": player_id, "profile": weakref(profile) if profile != null else null, "stamp": value_stamp, "role": role, "writable": writable, "available": available}
	result.make_read_only()
	return result

static func capture(observation: Dictionary) -> Dictionary:
	if not _eligible(observation): return _empty()
	# Rebuild to detach even a caller-constructed mutable observation.
	return snapshot(observation.player_id, observation.profile.get_ref(), observation.stamp, observation.role, true, true)

static func is_current(origin: Dictionary, observation: Dictionary) -> bool:
	if not _eligible(origin) or not _eligible(observation): return false
	return origin.player_id == observation.player_id and origin.role == observation.role and origin.stamp == observation.stamp and origin.profile.get_ref() == observation.profile.get_ref()

static func _eligible(value: Dictionary) -> bool:
	if typeof(value.get("player_id")) != TYPE_STRING_NAME or value.player_id == &"": return false
	if typeof(value.get("role")) != TYPE_STRING_NAME or value.role == &"": return false
	if typeof(value.get("writable")) != TYPE_BOOL or not value.writable: return false
	if typeof(value.get("available")) != TYPE_BOOL or not value.available: return false
	var profile: Variant = value.get("profile")
	if not profile is WeakRef or not profile.get_ref() is RefCounted: return false
	return _stamp_valid(value.get("stamp"))

static func _stamp_valid(stamp: Variant) -> bool:
	if not stamp is Array or stamp.size() != 5 or typeof(stamp[0]) != TYPE_STRING: return false
	for i in range(1, 5):
		if typeof(stamp[i]) != TYPE_INT: return false
	return true

## Optional physical-domain predicate. This does NOT grant profile effects:
## callers require is_current as well. Supply the real registered_id/body
## roundtrip, not a claimed id or local-player fallback. No roster lookup here.
static func physical_snapshot(player_id: StringName, body: Variant, actor: Variant, world: Variant, session: Variant, registered_id: StringName, registered_body: Variant) -> Dictionary:
	if player_id == &"" or player_id != registered_id or not is_instance_valid(body) or body != registered_body: return _empty()
	for node: Variant in [body, actor, world]:
		if not _live_node(node): return _empty()
	if session != null and not _live_node(session): return _empty()
	var result := {"player_id": player_id, "body": weakref(body), "actor": weakref(actor), "world": weakref(world), "session": weakref(session) if session != null else null}
	result.make_read_only()
	return result

static func capture_physical(observation: Dictionary) -> Dictionary:
	if not _physical_valid(observation): return _empty()
	return physical_snapshot(observation.player_id, observation.body.get_ref(), observation.actor.get_ref(), observation.world.get_ref(), observation.session.get_ref() if observation.session != null else null, observation.player_id, observation.body.get_ref())

static func is_physical_current(origin: Dictionary, observation: Dictionary) -> bool:
	if not _physical_valid(origin) or not _physical_valid(observation): return false
	if origin.player_id != observation.player_id: return false
	for key: String in ["body", "actor", "world", "session"]:
		if origin[key] == null or observation[key] == null:
			if origin[key] != observation[key]: return false
		elif origin[key].get_ref() != observation[key].get_ref(): return false
	return true

static func _physical_valid(value: Dictionary) -> bool:
	if typeof(value.get("player_id")) != TYPE_STRING_NAME or value.player_id == &"": return false
	for key: String in ["body", "actor", "world"]:
		if not value.get(key) is WeakRef or not _live_node(value[key].get_ref()): return false
	if not value.has("session"): return false
	return value.session == null or (value.session is WeakRef and _live_node(value.session.get_ref()))

static func _live_node(value: Variant) -> bool:
	return is_instance_valid(value) and value is Node and value.is_inside_tree() and not value.is_queued_for_deletion()

## Request/attachment identity is independent of profile effects. A serial
## distinguishes requests reusing one live source; null/expired never matches.
static func attachment(source: Object, serial: int) -> Dictionary:
	if not is_instance_valid(source): return _empty()
	var result := {"source": weakref(source), "serial": serial}
	result.make_read_only()
	return result

static func is_attachment_current(origin: Dictionary, source: Object, serial: int) -> bool:
	if not is_instance_valid(source) or not origin.get("source") is WeakRef or typeof(origin.get("serial")) != TYPE_INT: return false
	var original: Variant = origin.source.get_ref()
	return is_instance_valid(original) and original == source and origin.serial == serial

static func _empty() -> Dictionary:
	var result := {}
	result.make_read_only()
	return result
