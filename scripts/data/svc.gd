class_name Svc
extends RefCounted
## Late-bound access to autoloads and static helper classes from class_name scripts.
##
## Why: a script that names an autoload identifier does not compile in a `-s` tool driver (drivers compile before the
## autoloads exist, plan Appendix B), and a direct reference to a class that a LATER package adds is a parse error until
## that package landed and `--import` ran. These helpers look things up at call time instead:
##   Svc.node("EconomyManager")                 the autoload node (or null)
##   Svc.override("FurnitureManager", fake)     a test injects a fake autoload (Svc.clear_overrides() removes all of them)
##   Svc.static_call(path, method, args, fb)    calls a STATIC function of a script that may not exist yet
##   Svc.lua_config("rarity_tiers", default)    LuaRuntime.get_config without naming the autoload

static var _overrides: Dictionary = {}


## The autoload `autoload_name` (an injected fake wins), or null when it does not exist.
static func node(autoload_name: Variant) -> Node:
	var key := str(autoload_name)
	if _overrides.has(key):
		var fake: Variant = _overrides[key]
		if is_instance_valid(fake):
			return fake as Node
		_overrides.erase(key)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(key)


## Makes node(autoload_name) answer `fake` until clear_overrides(). The fake only has to offer the methods the caller uses.
static func override(autoload_name: Variant, fake: Node) -> void:
	_overrides[str(autoload_name)] = fake


static func clear_overrides() -> void:
	_overrides.clear()


static func has_override(autoload_name: Variant) -> bool:
	return _overrides.has(str(autoload_name))


## Calls the static function `method` of the script at `path` (e.g. "res://scripts/economy/price_curve.gd") with `args`.
## Late binding: the script is only loaded when ResourceLoader.exists(path); when the script or the method is missing
## the `fallback` is returned (no error, no warning). Verified in Godot 4.7.2: Script.callv reaches static functions.
static func static_call(path: String, method: StringName, args: Array = [], fallback: Variant = null) -> Variant:
	if not ResourceLoader.exists(path):
		return fallback
	var script: Variant = load(path)
	if not (script is Script) or not (script as Script).has_method(method):
		return fallback
	for m in (script as Script).get_script_method_list():
		if str(m["name"]) == str(method) and (int(m["flags"]) & METHOD_FLAG_STATIC) == 0:
			return fallback                    # an instance method cannot be called on the script itself
	return (script as Script).callv(method, args)


## LuaRuntime.get_config(path, default) without naming the autoload; `default_value` when there is no LuaRuntime.
static func lua_config(path: String, default_value: Variant = null) -> Variant:
	var lr := node("LuaRuntime")
	return lr.get_config(path, default_value) if lr != null else default_value
