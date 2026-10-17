extends RefCounted
const SECTION := "cheat_ui_audit"
func run(t) -> void: await UiAudit.audit_screen(t,"cheats")
func run_windowed(t) -> void: await UiAudit.audit_screen(t,"cheats")
