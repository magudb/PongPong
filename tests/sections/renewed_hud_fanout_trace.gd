extends RefCounted
const SECTION := "renewed_hud_fanout_trace"
const TIMEOUT_S := 120.0
func run(t) -> void:
	await t.start_world()
	t.autoload("GameManager").clear_flag(&"intro_pending")
	t.autoload("SaveManager").autosave_enabled = false
	t.check("genuine_absent_p1_before_raw_notification", not PlayerRegistry._states.has(&"p1"))
	for connection in EventBus.quest_accepted.get_connections():
		var callback: Callable = connection.callable
		var target: Object = callback.get_object()
		var script_path: String = target.get_script().resource_path if target.get_script() != null else "native"
		var before: bool = PlayerRegistry._states.has(&"p1")
		PlayerRegistry.for_player(&"p1", func(): callback.call(&"p0", &"zz_hud_model"))
		var after: bool = PlayerRegistry._states.has(&"p1")
		t.info("HUD_FANOUT_TARGET "+JSON.stringify({"path":str(target.get_path()) if target is Node else "object", "source":script_path, "method":str(callback.get_method()), "before_p1":before, "after_p1":after, "keys":PlayerRegistry._states.keys()}))
		if before != after: break
	t.check("diagnostic_caller_unwound", PlayerRegistry._acting_id == &"")
