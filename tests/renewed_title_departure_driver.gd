extends SceneTree
# Compile the real fixture only AFTER autoload installation (standalone bootstrap).
var result := {"checks":{},"completed":false}
var report_path := ""
var mode := "modal"
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
	_run.call_deferred()
func check(id: String, value: bool) -> void:
	result.checks[id] = value
	print(("ok " if value else "FAIL ")+id)
func _run() -> void:
	var fixture: Variant = load("res://tests/sections/renewed_title_departure.gd").new()
	await fixture.run_driver(self)
	result.completed = true
	result["success"] = result.checks.values().all(func(value): return value)
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if result.success else 1)
func _finalize() -> void:
	result["finalized"] = true
	if not result.completed: result["success"] = false
	if not report_path.is_empty():
		var file := FileAccess.open(report_path,FileAccess.WRITE)
		file.store_string(JSON.stringify(result,"  ")); file.close()
	print("TITLE_DRIVER_RESULT "+JSON.stringify(result))
