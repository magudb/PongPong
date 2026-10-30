extends SceneTree
## Real no-autoload bootstrap; invoke using a project with no [autoload] section.
const Resolver := preload("res://scripts/towns/routines.gd")
var checks := 0
var failed := 0

class Facade extends Node:
	var decision := false
	var calls := 0
	var original: Dictionary = {}
	var received_original := false
	func reset_current(origin: Dictionary) -> bool:
		calls += 1
		received_original = is_same(origin, original)
		return decision

func _initialize() -> void:
	_run.call_deferred()

func check(id: String, ok: bool) -> void:
	checks += 1
	failed += int(not ok)
	print(("PASS " if ok else "FAIL ") + "routines_bootstrap." + id)

func warm() -> void:
	Resolver._tl = {"timeline": 1}
	Resolver._fb = {"festival": 2}
	Resolver._plans = {"plan": 3}
	Resolver._plans_day = 4
	Resolver.compile_problems.assign(["probe"])

func memos_intact() -> bool:
	return Resolver._fb == {"festival": 2} and Resolver._plans == {"plan": 3} and Resolver._plans_day == 4

func _run() -> void:
	check("no_autoloads", root.get_child_count() == 0)
	var helper: GDScript = load("res://scripts/player/operation_origin.gd")
	var profile := RefCounted.new()
	var observation: Dictionary = helper.snapshot(&"p0", profile, ["bootstrap", 0, 0, 0, 0], &"offline", true, true)
	check("pure_helper_no_services", helper.is_current(helper.capture(observation), observation) and root.get_child_count() == 0)
	warm()
	Resolver.clear_cache()
	check("empty_clear_local", Resolver._tl.is_empty() and Resolver._fb.is_empty() and Resolver._plans.is_empty() and Resolver._plans_day == -1 and Resolver.compile_problems.is_empty())
	check("context_local", Resolver.make_ctx(2, 12.0).weekday == 2 and root.get_child_count() == 0)
	var origin := {"stamp": ["probe", 0, 0, 0, 0], "profile": null}
	warm()
	Resolver._end_session(origin)
	check("missing_service_refuses", memos_intact() and root.get_child_count() == 0)
	var incompatible := Node.new()
	Svc.override("EventBus", incompatible)
	Resolver._end_session(origin)
	check("incompatible_service_refuses", memos_intact())
	Svc.clear_overrides()
	incompatible.free()
	var facade := Facade.new()
	facade.original = origin
	Svc.override("EventBus", facade)
	Resolver._end_session(origin)
	check("facade_false_refuses", memos_intact() and facade.calls == 1 and facade.received_original)
	facade.decision = true
	Resolver._end_session(origin)
	check("facade_true_synchronous", facade.calls == 2 and facade.received_original and Resolver._fb.is_empty() and Resolver._plans.is_empty() and Resolver._plans_day == -1)
	check("session_only_memos", Resolver._tl == {"timeline": 1} and Resolver.compile_problems == ["probe"])
	warm()
	Resolver._end_session({})
	check("explicit_empty_bypasses_facade", facade.calls == 2 and Resolver._fb.is_empty())
	Svc.clear_overrides()
	facade.free()
	check("no_service_created", root.get_child_count() == 0)
	Resolver.clear_cache()
	print("BOOTSTRAP checks=", checks, " failed=", failed)
	quit(int(failed > 0))
