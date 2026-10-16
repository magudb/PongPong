extends RefCounted
func run(t, suite) -> void:
	var result: Dictionary = t.run_tool("python3", [ProjectSettings.globalize_path("res://tools/town/audit_copy.py")])
	var data: Variant = JSON.parse_string(str(result.output))
	if not data is Dictionary:
		suite._check(t, "L17", "l17_copy_audit_runs", false, str(result))
		return
	for id in data.checks:
		suite._check(t, "L17", "l17_" + str(id), bool(data.checks[id]), str(data.get("note", "")))
	suite._check(t, "L17", "l17_observed_screens_have_no_raw_keys", suite.text_samples >= 100 and suite.raw_copy.is_empty(), "%d live labels / %s" % [suite.text_samples, str(suite.raw_copy)])
	var indexed: Dictionary = t.run_tool("python3", [ProjectSettings.globalize_path("res://tools/voice/build_index.py"), "--check"])
	suite._check(t, "L17", "l17_voice_index_and_missing_recordings", indexed.code == 0 and data.unrecorded_hooks.size() >= 110, indexed.output)
