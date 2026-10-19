extends SceneTree
## Lua lint tool (plan R.2): checks Lua files against the interpreted subset (scripts/data/lua_lint.gd) and prints one
## PASS / FAIL line per file, the format tests/lib `expect_tool_ids` understands. Exit code 0 = every file clean.
##
##   godot --headless --path . -s res://tools/lua/lint.gd                       lints every file under res://lua
##   godot --headless --path . -s res://tools/lua/lint.gd -- --root=res://lua/quests --root=res://tests/fixtures/lua
##   godot --headless --path . -s res://tools/lua/lint.gd -- --files=res://lua/quests/lost_cat.lua,/abs/other.lua
##   options: --list-rules  print the rule ids and exit      --quiet  no PASS lines, only FAIL lines and the summary
##
## Output lines:   PASS <path>                                  the file is clean
##                 FAIL <path>:<line>:<rule> <message>          one line per finding
##                 lint: <files> file(s), <findings> finding(s) summary line
## The data-level lint findings of LuaRuntime (a config key defined by two files, a rarity not on the ladder, a `tables`
## header without its table, a `kind = "registry"` file without its `registry = "<name>"` header and table) are added when
## the default root res://lua is linted; they need the loaded runtime, the token rules do not. Consistency notes (an id
## defined twice) are printed as NOTE lines and never fail the run.
## Autoloads do not exist when this script compiles: everything is reached through load() and root.get_node().

const _Lint := preload("res://scripts/data/lua_lint.gd")
const DATA_LEVEL_RULES := ["duplicate_key", "rarity", "tables_header", "registry_header"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame                       # the autoloads' _ready() has run (LuaRuntime has loaded res://lua)
	var roots: Array[String] = []
	var files: Array[String] = []
	var quiet := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--root="):
			roots.append(a.substr(7))
		elif a.begins_with("--files="):
			for f in a.substr(8).split(",", false):
				files.append(f)
		elif a == "--quiet":
			quiet = true
		elif a == "--list-rules":
			print("rules: else elseif loop long_bracket local_function module_function escape length stdlib method_call vararg arithmetic bitwise mixed_table reserved_key table_value nil_value kind_missing kind_unknown unbalanced unterminated_string stray_character unknown_function | grammar: syntax local_list field_assignment function_value unsupported top_level | data level: duplicate_key rarity tables_header registry_header")
			quit(0)
			return
	var default_root := roots.is_empty() and files.is_empty()
	if default_root:
		roots.append("res://lua")
	for r in roots:
		_collect(r, files)
	files.sort()
	var findings_total := 0
	var by_file := {}
	for path in files:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			print("FAIL %s:0:unreadable cannot read the file" % path)
			findings_total += 1
			continue
		var findings: Array[Dictionary] = _Lint.lint(file.get_as_text(), path)
		file.close()
		by_file[path] = findings
	if default_root:
		var lr := root.get_node_or_null("LuaRuntime")
		if lr != null:
			for f in lr.lint_report:
				if str(f["rule"]) in DATA_LEVEL_RULES:
					var p := str(f["path"])
					if not by_file.has(p):
						by_file[p] = []
					(by_file[p] as Array).append(f)
	var paths := by_file.keys()
	paths.sort()
	for path in paths:
		var findings: Array = by_file[path]
		if findings.is_empty():
			if not quiet:
				print("PASS %s" % path)
			continue
		for f in findings:
			findings_total += 1
			print("FAIL %s:%d:%s %s" % [path, int(f["line"]), str(f["rule"]), str(f["message"])])
	if default_root:
		var lr2 := root.get_node_or_null("LuaRuntime")
		if lr2 != null:
			for n in lr2.data_report:
				print("NOTE %s: %s" % [str(n["path"]), str(n["message"])])
	print("lint: %d file(s), %d finding(s)" % [paths.size(), findings_total])
	quit(0 if findings_total == 0 else 1)


## every *.lua below `dir_path` (recursive, sorted by the caller)
func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := dir_path.path_join(entry)
			if dir.current_is_dir():
				_collect(full, out)
			elif entry.get_extension() == "lua":
				out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
