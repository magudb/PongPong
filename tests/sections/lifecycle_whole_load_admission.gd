extends RefCounted
const SECTION := "lifecycle_whole_load_admission"
const TIMEOUT_S := 90.0
class Probe extends Node:
	var hook: Callable
	var snapshots := 0
	var validations := 0
	var applications := 0
	func to_dict() -> Dictionary:
		snapshots += 1
		return {"v":1}
	func validate_dict(_d: Dictionary) -> bool:
		validations += 1
		if hook.is_valid(): hook.call()
		return true
	func from_dict(_d: Dictionary) -> bool:
		applications += 1
		return true
	func reset() -> void: pass
func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var saves: Node = t.autoload("SaveManager")
	var bus: Node = t.autoload("EventBus")
	saves.autosave_enabled = false
	saves.save_dir = "user://whole_load_admission"
	var original_scene: String = saves.world_scene
	t.on_cleanup(func(): saves.world_scene = original_scene)
	saves.world_scene = "res://tests/fixtures/whole_load_missing.tscn"
	var p := Probe.new()
	t.root.add_child(p)
	saves.register_section("whole_load_probe",p,999)
	t.check("idle_save_positive",saves.save_game(0))
	var callbacks := [0,0]
	var signals := [0]
	var notification := func(_a,_b,_c): signals[0] += 1
	bus.notification_posted.connect(notification)
	for boundary in ["validation","completion"]:
		var armed := [true]
		var results: Array = []
		var observer := func(_slot = 0):
			if not armed[0]: return
			armed[0] = false
			callbacks[0 if boundary == "validation" else 1] += 1
			var token: RefCounted = gm.get("_lifecycle_token")
			var before := _state(saves,p,signals)
			for method in [&"_load_game_owned",&"_load_and_enter_owned",&"_continue_latest_owned"]:
				before = _state(saves,p,signals)
				var accepted := false
				if saves.has_method(method):
					accepted = saves.call(method,token) if method == &"_continue_latest_owned" else saves.call(method,0,token)
				results.append({"method":str(method),"accepted":accepted,"unchanged":before == _state(saves,p,signals)})
			before = _state(saves,p,signals)
			results.append({"public":saves.try_load_game(5),"unchanged":before == _state(saves,p,signals)})
		if boundary == "validation": p.hook = observer
		else: bus.load_completed.connect(observer,CONNECT_ONE_SHOT)
		var outer: Dictionary = saves.try_load_game(0)
		p.hook = Callable()
		t.check(boundary+"_exact_token_whole_load_refused_before_any_effect",results.size() == 4 and results.slice(0,3).all(func(row):return not row.accepted and row.unchanged),str(results))
		t.check(boundary+"_public_root_busy_without_status_mutation",results.size() == 4 and results[3].public.code == "busy" and results[3].unchanged,str(results))
		t.check(boundary+"_outer_and_next_idle_positive",outer.ok and not gm.lifecycle_busy() and saves.try_load_game(0).ok)
	t.check("both_real_callback_boundaries_reached",callbacks == [1,1],str(callbacks))
	bus.notification_posted.disconnect(notification)
	saves.unregister_section("whole_load_probe")
	p.free()
func _state(saves: Node,p: Node,signals: Array) -> Dictionary:
	return {"last":saves.last_error.duplicate(true),"slot":saves.current_slot,"run":saves.run_id,"pending":saves.pending_world.duplicate(true),"snapshots":p.snapshots,"validations":p.validations,"applications":p.applications,"notifications":signals[0]}
