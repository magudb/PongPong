extends RefCounted
## Harness self-test: t.run_godot_script() / parse_tool_ids() run a child Godot driver and read its PASS/FAIL ids.
const SECTION := "tool_wrap"

func run(t) -> void:
	var r: Dictionary = t.run_godot_script("res://tests/lib/selftest/tool_ok/_fake_tool.gd")
	t.expect_eq(int(r["code"]), 1, "the child driver's exit code arrives")
	var ids: Dictionary = t.parse_tool_ids(r)
	t.expect_eq(ids["pass"], ["fake.one", "fake.three"], "PASS ids are parsed in order")
	t.expect_eq(ids["fail"], ["fake.two"], "FAIL ids are parsed")
	var missing: Dictionary = t.run_tool("/definitely/not/a/program")
	t.expect(int(missing["code"]) != 0, "a program that cannot start gives a non-zero code (%s)" % str(missing["code"]))
