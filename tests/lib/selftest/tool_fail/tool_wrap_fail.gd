extends RefCounted
## Harness self-test (NEGATIVE): expect_tool_ids() turns a FAIL line and a non-zero exit code of the wrapped tool
## into failed checks named <section>.<id> and <section>.tool_exit_code.
const SECTION := "tool_wrap_fail"

func run(t) -> void:
	var n: int = t.expect_tool_ids(t.run_godot_script("res://tests/lib/selftest/tool_fail/_fake_tool.gd"), "fake_tool")
	t.expect_eq(n, 3, "three ids were wrapped")
