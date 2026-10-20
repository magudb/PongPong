extends RefCounted
const SECTION := "copy_rules"

func run(t) -> void:
	var sheet := FileAccess.get_file_as_string("res://docs/copy/STYLE_SHEET.md")
	for i in range(1, 12):
		t.expect(sheet.contains("## R%d\n" % i), "Style rule R%d is documented" % i)
	var arch := FileAccess.get_file_as_string("res://docs/copy/ARCHETYPES.md")
	for id in ["child", "wanderer", "fairy", "shopkeeper", "gardener", "watcher", "elder", "craftsman"]:
		t.expect(arch.contains("## " + id + "\n"), "Voice sheet: " + id)
	var glossary := FileAccess.get_file_as_string("res://docs/copy/GLOSSARY.md")
	var loc: Node = t.autoload("LocalizationManager")
	for npc in SocialData.npcs().values():
		t.expect(glossary.contains(loc.text_in(str(npc.get("name_key", "")), "da")), "Glossary retains every approved display name")
	var python := ProjectSettings.globalize_path("res://tools/art/.venv/bin/python")
	t.expect_tool_ids(t.run_tool(python, ["-I", ProjectSettings.globalize_path("res://tools/copy/measure_fonts.py"), "--check"]), "Shipped font metrics")
	t.expect_tool_ids(t.run_tool(t.python(), [ProjectSettings.globalize_path("res://tools/copy/test_copy_lint.py")]), "Copy mutants")
	var result: Dictionary = t.run_tool(t.python(), [ProjectSettings.globalize_path("res://tools/copy/copy_lint.py"), "--strict", "--json"])
	t.check("strict_lint_runs_clean", result.code == 0, result.output)
	var findings: Variant = JSON.parse_string(result.output)
	t.check("legacy_copy_findings_cleared", findings is Array and findings.is_empty(), str(findings))
	var status: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/copy/review_status.json"))
	for key in status:
		t.expect(FileAccess.file_exists("res://" + key) and status[key].status in ["draft", "ai_reviewed", "native_reviewed"], "Honest review state for " + key)
