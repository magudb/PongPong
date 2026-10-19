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
## "path::method" -> the Script whose STATIC function static_call / static_await may call, or null when there is none.
## Resolving costs 24-77 µs (exists + load + the whole method list) and hot paths call it several times per physics tick,
## so a res:// answer is remembered (a shipped script does not change while the game runs); user:// probe scripts of the
## tests are resolved on every call (a test may rewrite one under the same path).
static var _resolved: Dictionary = {}


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
## Late binding: the script is only loaded when ResourceLoader.exists(path); when the script is missing the `fallback` is
## returned silently. A res:// script that exists but has no STATIC function of that name is a broken contract (a rename):
## the caller gets the fallback and the engine warns once. Verified in Godot 4.7.2: Script.callv reaches static functions.
static func static_call(path: String, method: StringName, args: Array = [], fallback: Variant = null) -> Variant:
	var script := _static_script(path, method)
	if script == null:
		return fallback
	return script.callv(method, args)


## LuaRuntime.get_config(path, default) without naming the autoload; `default_value` when there is no LuaRuntime.
static func lua_config(path: String, default_value: Variant = null) -> Variant:
	var lr := node("LuaRuntime")
	return lr.get_config(path, default_value) if lr != null else default_value


## Async counterpart: the late-bound caller must await callv itself. Returning
## an un-awaited coroutine through static_call loses its result in Godot 4.
static func static_await(path: String, method: StringName, args: Array = [], fallback: Variant = null) -> Variant:
	var script := _static_script(path, method)
	if script == null:
		return fallback
	return await script.callv(method, args)


## The script at `path` when it has a STATIC function `method`, else null (remembered for res://, see _resolved).
static func _static_script(path: String, method: StringName) -> Script:
	var key := "%s::%s" % [path, method]
	if _resolved.has(key):
		return _resolved[key]
	var found: Script = null
	if ResourceLoader.exists(path):
		var script: Variant = load(path)
		if script is Script:
			var is_static := false
			if (script as Script).has_method(method):
				for m in (script as Script).get_script_method_list():
					if str(m["name"]) == str(method):
						is_static = (int(m["flags"]) & METHOD_FLAG_STATIC) != 0   # an instance method cannot be called on the script
			if is_static:
				found = script
			elif path.begins_with("res://"):
				push_warning("Svc.static_call: %s has no static function %s(): the caller gets its fallback" % [path, method])
	if path.begins_with("res://"):
		_resolved[key] = found
	return found
