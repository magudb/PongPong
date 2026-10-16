class_name ContractManifest
extends RefCounted
## Boot-time visibility for the wave packages that a missing script / scene silently replaces.
##
## The package architecture (Svc, ResourceLoader.exists gates, lazy marker handlers) lets a feature
## land later without breaking anything - the cost is that a package that NEVER lands is invisible:
## player_2d.tscn missing means PlayerStub2D is the shipped player, shop_rotation.gd missing means
## fixed stock, farm_grid.gd missing means no crop model. Tests know; the running game does not.
##
## This list is the other half of those gates. CHECK IT AT WORLD BOOT (WorldRoot2D._ready) and post
## ONE diagnostic event naming the fallbacks that are active. Developer package names and paths
## belong in diagnostics, never in the player's notification stack.
##
## CONTRACT of an entry:
##   path     res:// path of the resource the late-binding gate looks for
##   fallback what is used instead (a class, "fixed stock", "no crop model", ...)
##   owner    the wave / package that is supposed to ship it (goes in the toast so a reader knows who to ask)
##
## A path that EXISTS is fine. A path that is missing is listed in missing() and named in report().
## Entries must stay in sync with the gates that consume them (world_2d.gd, shop_system.gd, iso_area.gd).

const EXPECTED: Array[Dictionary] = [
	{"path": "res://scenes/world2d/player_2d.tscn", "fallback": "PlayerStub2D", "owner": "P06"},
	{"path": "res://scripts/world2d/farm_grid.gd", "fallback": "no crop model", "owner": "P06"},
	{"path": "res://scripts/world2d/farm_view.gd", "fallback": "no crop view", "owner": "P06"},
	{"path": "res://scripts/economy/shop_rotation.gd", "fallback": "fixed shop stock", "owner": "F4"},
	{"path": "res://scripts/economy/price_curve.gd", "fallback": "base price x buy_multiplier", "owner": "F4"},
	{"path": "res://scripts/world2d/intro_sequence.gd", "fallback": "no opening sequence", "owner": "P14"},
]

## One notification is posted per process even if several worlds boot (quit to menu and back).
static var _reported: bool = false


## The entries whose resource is not on disk. Empty = every contract is met.
static func missing() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in EXPECTED:
		if not ResourceLoader.exists(str(e["path"])):
			out.append(e)
	return out


static func is_complete() -> bool:
	return missing().is_empty()


## "player_2d.tscn -> PlayerStub2D (P06); farm_grid.gd -> no crop model (P06)" - one line, for logs and tests.
static func describe(gaps: Array[Dictionary] = []) -> String:
	if gaps.is_empty():
		gaps = missing()
	var parts: PackedStringArray = []
	for e in gaps:
		parts.append("%s -> %s (%s)" % [str(e["path"]).get_file(), str(e["fallback"]), str(e["owner"])])
	return "; ".join(parts)


## Publishes ONE diagnostic when anything is missing. Silent when complete
## or when it already reported. `force` re-posts (tests).
static func report(force: bool = false) -> void:
	if _reported and not force:
		return
	var gaps := missing()
	if gaps.is_empty():
		_reported = true
		return
	_reported = true
	var bus: Node = _bus()
	if bus == null:
		return
	bus.emit_signal("game_event", &"contract_fallbacks", {"gaps": gaps.duplicate(true)})


## Clears the one-shot flag (tests that want a fresh report).
static func reset() -> void:
	_reported = false


static func _bus() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	var root: Window = (loop as SceneTree).root if loop is SceneTree else null
	return root.get_node_or_null(NodePath("EventBus")) if root != null else null
