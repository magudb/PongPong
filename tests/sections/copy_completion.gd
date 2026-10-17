extends RefCounted
const SECTION := "copy_completion"
const TIMEOUT_S := 120.0
func run(t) -> void:
	var output := ProjectSettings.globalize_path("res://docs/qa/mechanics/copy/loc-refs.json")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var snapshot: Dictionary = t.run_tool(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"-s","res://tests/loc_check.gd","--","--strict","--dump="+output])
	t.check("strict_runtime_localization",snapshot.code==0,str(snapshot.output))
	for file in ["tools/loc/csv_lint.py","tools/copy/copy_lint.py"]:
		var result: Dictionary = t.run_tool("python3",[ProjectSettings.globalize_path("res://"+file),"--strict"])
		t.check(file.get_file()+"_strict",result.code==0,str(result.output))
	await _fixture_boundaries(t)
	var voices: Dictionary = t.run_tool("python3",[ProjectSettings.globalize_path("res://tools/voice/generate_voice.py"),"--check"])
	t.check("all_reviewed_voice_assets_match",voices.code==0,str(voices.output))

func _fixture_boundaries(t) -> void:
	var root := ProjectSettings.globalize_path("user://copy-fixture-boundaries")
	for folder in ["localization","scripts/ui/dev"]:DirAccess.make_dir_recursive_absolute(root.path_join(folder))
	var fixture := 'static func fixture_guide():\n var rows = [{"text_key":"GUIDE_TEST"}]\n'
	var source := root.path_join("scripts/ui/dialogue_ui.gd")
	var file := FileAccess.open(source,FileAccess.WRITE)
	file.store_string(fixture)
	file.close()
	file = FileAccess.open(root.path_join("scripts/ui/dev/guide_fixture.json"),FileAccess.WRITE)
	file.store_string('{"texts":{"GUIDE_TEST":"Fixture copy"}}')
	file.close()
	var args := ["--headless","--path",ProjectSettings.globalize_path("res://"),"-s","res://tests/loc_check.gd","--","--root="+root]
	var supplied: Dictionary = t.run_tool(OS.get_executable_path(),args)
	t.check("fixture_copy_requires_its_data",not str(supplied.output).contains("MISS da,en GUIDE_TEST"))
	file = FileAccess.open(source,FileAccess.WRITE)
	file.store_string(fixture+'func live_dialogue():\n var row = {"text_key":"GUIDE_TEST"}\n')
	file.close()
	var live: Dictionary = t.run_tool(OS.get_executable_path(),args)
	t.check("fixture_key_in_product_still_requires_csv",str(live.output).contains("MISS da,en GUIDE_TEST"))
	file = FileAccess.open(source,FileAccess.WRITE)
	file.store_string(fixture.replace("GUIDE_TEST","GUIDE_UNKNOWN"))
	file.close()
	var unknown: Dictionary = t.run_tool(OS.get_executable_path(),args)
	t.check("unknown_fixture_key_still_fails",str(unknown.output).contains("MISS da,en GUIDE_UNKNOWN"))
