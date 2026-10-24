class_name PlayerRegistry
## Player identity lookup (MP1-player-registry).
##
## NEVER use `get_first_node_in_group("player")` for identity. Group `player` stays for physics / area
## queries (`body.is_in_group("player")`); who "the player" is goes through here or WorldRoot2D's helpers.
## Single-player: there is one local player (`p0`, peer 1) and these helpers return it.

const PLAYER_GROUP := &"player"
const WORLD_GROUP := &"world_2d"
const MAX_PLAYERS := 4

## Shared `p0` row used while no WorldRoot2D roster exists (autoload boot, unit tests).
## The managers must see the same row or they diverge.
static var _fallback_state := PlayerState.new()
static var _states: Dictionary = {&"p0": _fallback_state}
static var _acting_id: StringName = &""


## Synchronous actor scope for host-side operations; restored even when scopes nest.
static func for_player(player_id: StringName, work: Callable) -> Variant:
	var previous := _acting_id
	_acting_id = player_id
	var result: Variant = work.call()
	_acting_id = previous
	return result


static func acting_id() -> StringName:
	return _acting_id if _acting_id != &"" else local_id()


static func reset_states() -> void:
	_fallback_state = PlayerState.new()
	_states = {&"p0": _fallback_state}


## The acting player's session row, retained while no world scene exists.
static func state(player_id: StringName = &"", tree: SceneTree = null) -> PlayerState:
	var id := player_id if player_id != &"" else (_acting_id if _acting_id != &"" else local_id(tree))
	if not _states.has(id):
		_states[id] = PlayerState.new(id, int(str(id).trim_prefix("p")) + 1)
	return _states[id]



## The live WorldRoot2D, or null when no world is in the tree.
static func world(tree: SceneTree = null) -> Node:
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group(WORLD_GROUP)


## The player this machine controls. Prefers the first body in group `player` (the historical
## contract every call site had; test fixtures plant their own Node there), then the world
## registry. Returns Node on purpose: fixtures may be plain Nodes, not Node2D.
static func local_player(tree: SceneTree = null) -> Node:
	var body := _first_body(tree)
	if body != null:
		return body
	var w := world(tree)
	if w != null and w.has_method("local_player"):
		var p: Variant = w.call("local_player")
		if p is Node:
			return p as Node
	return null


## Save id of the local player (`p0` when nothing is up). What player-scoped EventBus signals carry (MP3).
static func local_id(tree: SceneTree = null) -> StringName:
	var p := local_player(tree)
	if p != null and "player_id" in p:
		return StringName(str(p.get("player_id")))
	return &"p0"


## Player by stable save id (`p0`..`p3`).
static func by_id(player_id: StringName, tree: SceneTree = null) -> Node:
	var w := world(tree)
	if w != null and w.has_method("player_by_id"):
		var p: Variant = w.call("player_by_id", player_id)
		if p is Node:
			return p as Node
	return null


## Resolve a live registered body, never a caller-supplied id or local fallback.
## Membership is checked before reading identity: an unregistered clone with
## player_id = p0 cannot borrow the real p0's quest/inventory row.
static func registered_id(body: Node) -> StringName:
	if not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion():
		return &""
	var w := world(body.get_tree())
	if w == null or not w.has_method("all_players"):
		return &""
	for registered in w.all_players():
		if registered == body and "player_id" in body:
			var id := StringName(str(body.get("player_id")))
			return id if id != &"" and by_id(id, body.get_tree()) == body else &""
	return &""


## Player by session peer id (1 = host). Null when no body owns that peer.
static func by_peer(peer_id: int, tree: SceneTree = null) -> Node:
	var w := world(tree)
	if w != null and w.has_method("player_by_peer_id"):
		var p: Variant = w.call("player_by_peer_id", peer_id)
		if p is Node:
			return p as Node
	return null


## Every registered player body, slot order (missing slots are skipped).
static func all_players(tree: SceneTree = null) -> Array:
	var w := world(tree)
	if w != null and w.has_method("all_players"):
		var a: Variant = w.call("all_players")
		if a is Array:
			return a as Array
	var one := _first_body(tree)
	return [] if one == null else [one]


## The player an input event belongs to. MP1: always the local player (device binding is MP2).
static func for_event(_event: InputEvent, tree: SceneTree = null) -> Node:
	return local_player(tree)


## Resolve the actor id used by social/event code ("player" = the local hero).
static func resolve_actor(id: String, tree: SceneTree = null) -> Node:
	if id == "player" or id == "":
		return local_player(tree)
	if id.begins_with("p") and id.length() >= 2:
		return by_id(StringName(id), tree)
	return null


static func _first_body(tree: SceneTree = null) -> Node:
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group(PLAYER_GROUP)
