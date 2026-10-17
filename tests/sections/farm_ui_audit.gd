extends RefCounted
const SECTION := "farm_ui_audit"
const TIMEOUT_S := 180.0
func run(t) -> void: await UiAudit.audit_screen(t,"build_menu")
func run_windowed(t) -> void:
	# compare_guide is normally delegated by UiAudit to the Python checkpoint.
	var checks: Array = UiAudit.screen("build_menu").checks.duplicate()
	checks.erase("compare_guide")
	await UiAudit.audit_screen(t,"build_menu", {"checks": checks})
	var result: Dictionary = t.run_tool(ProjectSettings.globalize_path("res://tools/art/.venv/bin/python"), PackedStringArray([
		ProjectSettings.globalize_path("res://tests/checkpoints/compare_guide.py"),
		"--ref", ProjectSettings.globalize_path("res://docs/qa/ui_baseline/build_menu.png"),
		"--no-frame-crop", "--max", "1.5", "--json",
		t.out_dir.path_join("farm_ui_audit_panel_pixels_build_menu.png")]))
	t.check("reviewed_build_menu_pixel_baseline", int(result.code) == 0, str(result.output))
