extends RefCounted
const SECTION := "inject_shutdown_warning"
static func _late_warning() -> void:
	push_warning("INJECTED-SHUTDOWN-WARNING")
func run(t) -> void:
	t.tree.root.tree_exiting.connect(_late_warning)
	t.check("shutdown_hook_installed",true)
