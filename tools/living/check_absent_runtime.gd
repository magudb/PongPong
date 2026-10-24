extends SceneTree
## Proves the absent-runtime reader contract without a fake catalogue/runtime.
## Temporarily detach the actual service; Godot instantiates autoloads before _initialize().
## godot --headless --path . -s res://tools/living/check_absent_runtime.gd


func _initialize() -> void:
	var runtime := Svc.node("LuaRuntime")
	if runtime != null:
		root.remove_child(runtime)
	var data: Script = load("res://scripts/social/living/living_data.gd")
	var checks := {
		"no_runtime_at_probe": Svc.node("LuaRuntime") == null,
		"empty_profiles": data.call("profiles").is_empty(),
		"empty_profile": data.call("profile", "baker_maja").is_empty(),
		"missing_runtime_not_coverage": data.call("validate").size() == 34,
		"explicit_empty_not_coverage": data.call("validate", {}).size() == 34,
	}
	var failures := 0
	for label in checks:
		print("%s absent_runtime.%s" % ["PASS" if checks[label] else "FAIL", label])
		if not checks[label]:
			failures += 1
	if runtime != null:
		root.add_child(runtime)
	quit(0 if failures == 0 else 1)
