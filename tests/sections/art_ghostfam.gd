extends RefCounted
const SECTION := "art_ghostfam"
const TIMEOUT_S := 60.0

func run(t) -> void:
	for id in ["ghostfam_dyne", "ghostfam_gnist", "ghostfam_silke", "ghostfam_blund"]:
		var path: String = "res://assets/isometric_characters/" + str(id) + "/"
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + "animations.json"))
		t.check(id + "_villager_clip_set", meta.role == "npc" and meta.clip_set == "villager" and meta.family == "ghost" and meta.animations.size() == 6)
		t.check(id + "_painted_source_resolves", FileAccess.file_exists("res://" + str(meta.illustration.source)) and FileAccess.file_exists("res://" + str(meta.illustration.north_source)))
		t.check(id + "_pivot_and_scale", Vector2(meta.pivot[0], meta.pivot[1]) == Vector2(128, 200) and Vector2(meta.cell_size[0], meta.cell_size[1]) == Vector2(256, 256) and float(meta.display_scale) == 1.0)
		var frames := 0
		for clip in meta.animations:
			frames += int(meta.animations[clip].frames)
			var texture: Texture2D = load(path + str(meta.animations[clip].sheet))
			t.check(id + "_" + clip + "_sheet_size", texture != null and texture.get_width() == 256 * int(meta.animations[clip].frames) and texture.get_height() == 2048)
		t.check(id + "_all_28_frames", frames == 28)
	var python := ProjectSettings.globalize_path("res://tools/art/.venv/bin/python")
	var source_gate: Dictionary = t.run_tool(python, [ProjectSettings.globalize_path("res://tools/art/ghost_family/check_sources.py")])
	t.check("sources_meet_authored_shape_plan", source_gate.code == 0, source_gate.output)
	var script := ProjectSettings.globalize_path("res://tools/art/ghost_family/measure_family.py")
	var result: Dictionary = t.run_tool(python, [script, ProjectSettings.globalize_path("res://assets/isometric_characters"), "--check", "--painted"])
	t.check("cast_gates_hold_on_painted_sheets", result.code == 0, result.output)
	result = t.run_tool(python, [script, "--selftest"])
	t.check("cast_gates_have_teeth", result.code == 0, result.output)
