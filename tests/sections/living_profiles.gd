extends RefCounted
## LC1 catalogue contracts only; no activity/relationship gameplay completion claimed.
const SECTION := "living_profiles"


func run(t) -> void:
	var lr: Node = t.autoload("LuaRuntime")
	var catalogue: Dictionary = lr.call("get_config", "living_citizens", {})
	t.check("runtime_pilot_profile", catalogue.has("baker_maja"),
		"real LuaRuntime config must explicitly author Rosmarin; no derived citizen fallback")
	var path := "res://scripts/social/living/living_data.gd"
	t.check("reader_exists", FileAccess.file_exists(path))
	if not FileAccess.file_exists(path):
		return
	var data: Script = load(path)
	t.check("reader_runtime_catalogue", data.call("profiles") == catalogue)
	t.check("reader_explicit_profile", data.call("profile", "baker_maja") == catalogue.get("baker_maja", {}))
	t.check("no_unknown_fallback", data.call("profile", "not_a_citizen").is_empty())
	var file := FileAccess.open("res://localization/living_characters.csv", FileAccess.READ)
	t.check("pilot_localization_file", file != null)
	if file != null:
		t.check("pilot_localization_da_en", file.get_as_text().contains("LC_BAKER_MAJA_PURPOSE")
			and file.get_as_text().contains("LC_BAKER_MAJA_ASPIRATION"))
	for npc in ["baker_maja", "beekeeper_birk", "smith_thorin"]:
		t.check("pilot_explicit_" + npc, catalogue.has(npc))
	t.check("validator_exists", data.has_method("validate"))
	if not data.has_method("validate"):
		return
	var errors: Array = data.call("validate", catalogue)
	t.check("explicit_empty_rejected", data.call("validate", {}).has("coverage:missing:baker_maja"))
	t.check("pilot_schema_valid", errors.filter(func(e): return not str(e).begins_with("coverage:")).is_empty(), str(errors))
	var canonical: Dictionary = lr.call("get_config", "npcs", {})
	var expected := canonical.keys()
	var actual := catalogue.keys()
	expected.sort()
	actual.sort()
	t.check("full_cast_exactly_34", expected.size() == 34 and actual == expected, "runtime identity IDs versus explicit authored IDs")
	t.check("full_cast_valid", errors.is_empty(), str(errors))
	t.check("omitted_uses_runtime", data.call("validate") == errors)
	var lm: Node = t.autoload("LocalizationManager")
	var copy_file := FileAccess.open("res://localization/living_characters.csv", FileAccess.READ)
	if copy_file != null:
		t.check("runtime_copy_header", copy_file.get_csv_line() == PackedStringArray(["keys", "da", "en"]))
		while not copy_file.eof_reached():
			var cells := copy_file.get_csv_line()
			if cells.size() != 3:
				continue
			t.check("copy_" + cells[0], lm.call("text_in", cells[0], "da") == cells[1]
				and lm.call("text_in", cells[0], "en") == cells[2], "actual DA/EN runtime texts")
	var dump_path := OS.get_environment("LC1_CATALOGUE_DUMP")
	if dump_path != "":
		var dump := FileAccess.open(dump_path, FileAccess.WRITE)
		t.check("dump_open", dump != null)
		if dump != null:
			dump.store_string(JSON.stringify({"catalogue": catalogue, "canonical": canonical, "validation": errors}, "  "))
	if not catalogue.has("smith_thorin") or LuaData.arr(catalogue.baker_maja.get("goals", [])).is_empty():
		return
	_negative_schema(t, data, catalogue)
	var empty_runtime: Node = load("res://scripts/autoload/lua_runtime.gd").new()
	var old_overrides := Svc._overrides.duplicate()
	Svc.override("LuaRuntime", empty_runtime)
	t.check("absent_config_empty", data.call("profiles").is_empty() and data.call("profile", "baker_maja").is_empty())
	t.check("absent_config_not_coverage", not data.call("validate").is_empty())
	Svc._overrides = old_overrides
	empty_runtime.free()


func _negative_schema(t, data: Script, catalogue: Dictionary) -> void:
	var mutations := {
		"missing_id": func(p): p.baker_maja.erase("id"),
		"duplicate_id": func(p): p.beekeeper_birk.id = "baker_maja",
		"missing_purpose": func(p): p.baker_maja.erase("purpose_key"),
		"unknown_tie": func(p): p.baker_maja.ties[0].target = "story:iva",
		"unknown_provenance": func(p): p.baker_maja.ties[0].provenance = "probably_old",
		"dangling_source": func(p): p.baker_maja.ties[0].source = "res://living_missing_source.txt",
		"dangling_localization": func(p): p.baker_maja.purpose_key = "LC_MISSING_KEY",
		"bad_value_weight": func(p): p.baker_maja.values.quiet = 0,
		"bad_goal_weight": func(p): p.baker_maja.goals[0].weight = 99,
		"unknown_value": func(p): p.baker_maja.goals[0].value = "unwritten_value",
		"missing_goal_id": func(p): p.baker_maja.goals[0].erase("id"),
		"duplicate_goal_id": func(p): p.baker_maja.goals[1].id = p.baker_maja.goals[0].id,
		"unknown_goal_kind": func(p): p.baker_maja.goals[0].kind = "fetch",
		"bad_bound": func(p): p.baker_maja.goals[0].cooldown_days = -1,
		"fractional_bound": func(p): p.baker_maja.goals[0].expires_days = 1.5,
		"dangling_resource": func(p): p.baker_maja.goals[0].resources = {"lc_missing_item": 1},
		"unknown_resolution": func(p): p.baker_maja.goals[0].resolutions[0].kind = "loot",
		"dangling_fallback": func(p): p.baker_maja.goals[0].fallback = "nowhere",
		"non_autonomous_fallback": func(p): p.baker_maja.goals[0].resolutions[0].kind = "attendance",
		"dangling_reconciliation": func(p): p.baker_maja.goals[0].reconciliation = "nowhere",
		"bad_reconciliation_kind": func(p): p.baker_maja.goals[0].resolutions[2].kind = "attendance",
		"goal_bound": func(p): p.baker_maja.goals.append_array(p.baker_maja.goals.duplicate(true)),
		"tie_bound": func(p):
			for i in 9: p.baker_maja.ties.append(p.baker_maja.ties[0].duplicate(true)),
		"generic_not_coverage": func(p): p.erase("smith_thorin"); p["generic"] = p.baker_maja.duplicate(true),
	}
	for label in mutations:
		var mutant := catalogue.duplicate(true)
		mutations[label].call(mutant)
		var errors: Array = data.call("validate", mutant)
		var meaningful := errors.filter(func(e): return not str(e).begins_with("coverage:"))
		if label == "generic_not_coverage":
			t.check("reject_" + label, errors.has("coverage:missing:smith_thorin") and errors.has("coverage:unknown:generic"))
		else:
			t.check("reject_" + label, not meaningful.is_empty(), str(errors))
