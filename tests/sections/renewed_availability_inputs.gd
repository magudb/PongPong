extends RefCounted
const SECTION := "renewed_availability_inputs"
const TIMEOUT_S := 120.0

func run(t) -> void:
	var exporter: Script = load("res://tools/social/core/export_availability.gd")
	var valid: Dictionary = exporter.collect_inputs(["res://lua/towns.lua"], [])
	t.check("real_towns_input_readable_sha256", valid.ok and valid.inputs.get("res://lua/towns.lua") == FileAccess.get_sha256("res://lua/towns.lua") and exporter.validate_inputs(valid.inputs) == "")
	var recursive: Dictionary = exporter.collect_inputs([], ["res://lua/routines"])
	t.check("required_directory_members_hashed", recursive.ok and not recursive.inputs.is_empty() and exporter.validate_inputs(recursive.inputs) == "")
	var missing: Dictionary = exporter.collect_inputs(["res://lua/config/towns.lua"], [])
	t.check("original_stale_input_refused", not missing.ok and missing.error == "unreadable input: res://lua/config/towns.lua")
	# The real directory exists but cannot be read as a declared FILE.
	var unreadable: Dictionary = exporter.collect_inputs(["res://lua"], [])
	t.check("existing_nonfile_input_refused", DirAccess.dir_exists_absolute("res://lua") and not unreadable.ok and unreadable.error == "unreadable input: res://lua")
	var directory: Dictionary = exporter.collect_inputs([], ["res://lua/renewed_availability_missing"])
	t.check("missing_required_directory_refused", not directory.ok and directory.error == "unreadable directory: res://lua/renewed_availability_missing")
	var out := "user://renewed_availability_inputs.json"
	var preserved := "user://renewed_availability_preserved.json"
	var file := FileAccess.open(preserved, FileAccess.WRITE)
	file.store_string("preserved original output\n")
	file.close()
	for label in ["empty", "nonhex", "missing", "unreadable"]:
		var inputs: Dictionary = valid.inputs.duplicate()
		var error := ""
		match label:
			"empty":
				inputs["res://lua/towns.lua"] = ""
				error = "invalid SHA256: res://lua/towns.lua"
			"nonhex":
				inputs["res://lua/towns.lua"] = "z".repeat(64)
				error = "invalid SHA256: res://lua/towns.lua"
			"missing":
				inputs["res://lua/config/towns.lua"] = "a".repeat(64)
				error = "unreadable input: res://lua/config/towns.lua"
			"unreadable":
				inputs["res://lua"] = "a".repeat(64)
				error = "unreadable input: res://lua"
		var result := {"inputs": inputs}
		var fresh_error: String = exporter.write_result(out, result)
		var preserved_error: String = exporter.write_result(preserved, result)
		t.check(label + "_exact_refusal_without_publication_or_overwrite", fresh_error == error and preserved_error == error and not FileAccess.file_exists(out) and FileAccess.get_file_as_string(preserved) == "preserved original output\n")
	var changed: Dictionary = valid.inputs.duplicate()
	changed["res://lua/towns.lua"] = "a".repeat(64)
	t.check("changed_input_digest_refused", exporter.write_result(out, {"inputs": changed}) == "SHA256 mismatch: res://lua/towns.lua" and not FileAccess.file_exists(out))
	t.check("empty_declared_map_refused", exporter.write_result(out, {"inputs": {}}) == "empty declared inputs" and not FileAccess.file_exists(out))
	var success: String = exporter.write_result(out, {"inputs": valid.inputs})
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(out))
	t.check("valid_helper_publication_exact_inputs", success == "" and decoded is Dictionary and decoded.inputs == valid.inputs)
