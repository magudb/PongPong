extends RefCounted
const SECTION := "tool_runner_isolation"
const TIMEOUT_S := 60.0

class Capture extends "res://tests/lib/t.gd":
	var commands: Array = []
	func run_tool(exe: String, args: PackedStringArray = PackedStringArray()) -> Dictionary:
		commands.append({"exe": exe, "args": args.duplicate()})
		return {"code": 0, "output": "", "lines": PackedStringArray()}

func run(t) -> void:
	var child_before := OS.get_environment("TT_TEST_CHILD_PROJECT")
	var python_before := OS.get_environment("TT_TEST_PYTHON")
	var journal_before := OS.get_environment("TT_TEST_TOOL_LOG_DIR")
	t.on_cleanup(func():
		OS.set_environment("TT_TEST_CHILD_PROJECT", child_before)
		OS.set_environment("TT_TEST_PYTHON", python_before)
		OS.set_environment("TT_TEST_TOOL_LOG_DIR", journal_before))
	var probe := Capture.new()
	var root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var peer := OS.get_environment("TT_ROUTING_CONTROL_PROJECT")
	var driver := OS.get_environment("TT_ROUTING_PROBE")
	if peer == "":
		peer = ProjectSettings.globalize_path("user://tool_runner_peer")
		DirAccess.make_dir_recursive_absolute(peer)
		var project := FileAccess.open(peer.path_join("project.godot"), FileAccess.WRITE)
		project.store_string("config_version=5\n[application]\nconfig/name=\"Tool route probe\"\n")
		project.close()
		driver = peer.path_join("probe.gd")
		var file := FileAccess.open(driver, FileAccess.WRITE)
		file.store_string("extends SceneTree\nfunc _initialize() -> void:\n	print(\"CHILD_PROJECT:\" + ProjectSettings.globalize_path(\"res://\"))\n	print(\"CHILD_HOME:\" + OS.get_environment(\"HOME\"))\n	quit(0)\n")
		file.close()
	t.check("explicit_distinct_control_project", peer.is_absolute_path() and peer != root and FileAccess.file_exists(peer.path_join("project.godot")))
	OS.set_environment("TT_TEST_CHILD_PROJECT", "")
	probe.run_godot_script("res://tests/tools/check_project.gd", PackedStringArray(["--text=res://project.godot"]))
	t.check("default_arguments_preserved_without_execution", probe.commands.size() == 1 and probe.commands[0].args == PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "res://tests/tools/check_project.gd", "--", "--text=res://project.godot"]))
	OS.set_environment("TT_TEST_CHILD_PROJECT", peer)
	probe.commands.clear()
	var configured: Dictionary = probe.run_godot_script("res://tests/tools/check_project.gd", PackedStringArray(["--text=res://project.godot"]))
	var routed: bool = configured.code == 0 and probe.commands.size() == 1 and probe.commands[0].args[2] == peer
	t.check("configured_child_uses_distinct_project", routed, str(probe.commands))
	var invalid_routes := ["relative/path", root, root + "/./", peer + "/missing"]
	for i in invalid_routes.size():
		var invalid: String = invalid_routes[i]
		OS.set_environment("TT_TEST_CHILD_PROJECT", invalid)
		probe.commands.clear()
		var refused: Dictionary = probe.run_godot_script("res://tests/tools/check_project.gd")
		t.check("invalid_route_refused_before_child_%d" % i, refused.code != 0 and probe.commands.is_empty(), invalid)
	var python_bin := OS.get_environment("TT_ROUTING_PYTHON")
	if python_bin == "": python_bin = "python" if OS.has_feature("windows") else "python3"
	OS.set_environment("TT_TEST_PYTHON", python_bin)
	t.check("explicit_python_bypasses_art_interpreter", probe.python() == python_bin, probe.python())
	OS.set_environment("TT_TEST_CHILD_PROJECT", peer)
	# Never launch a real child through the old same-project behavior during RED.
	if routed:
		var journal := ProjectSettings.globalize_path("user://tool_runner_journal")
		OS.set_environment("TT_TEST_TOOL_LOG_DIR", journal)
		var actual: Dictionary = t.run_godot_script(driver)
		t.check("real_child_project_and_exit", actual.code == 0 and actual.output.contains("CHILD_PROJECT:" + peer + "/"), actual.output)
		t.check("real_child_retains_throwaway_home", actual.output.contains("CHILD_HOME:" + OS.get_environment("HOME")), actual.output)
		var python: Dictionary = t.run_tool(t.python(), PackedStringArray(["-I", "-c", "import os,sys; print('PYTHON_HOME:' + os.environ['HOME']); print('PYTHON_BIN:' + sys.executable)"]))
		t.check("real_stdlib_python_retains_home", python.code == 0 and python.output.contains("PYTHON_HOME:" + OS.get_environment("HOME")), python.output)
		var started: Array = []
		var finished: Array = []
		if DirAccess.dir_exists_absolute(journal):
			for name in DirAccess.get_files_at(journal):
				var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(journal.path_join(name)))
				if record is Dictionary:
					if record.get("phase") == "started": started.append(record)
					if record.get("phase") == "finished": finished.append(record)
		t.check("real_tools_journal_start_and_exit_pairs", started.size() == 2 and finished.size() == 2)
		t.check("real_tools_journal_complete_stdout_and_stderr", finished.any(func(r): return r.get("code") == 0 and r.get("output") == actual.output) and finished.any(func(r): return r.get("code") == 0 and r.get("output") == python.output))
