extends RefCounted
## Harness self-test: t.require_tool() is true for a program that exists, and a missing one is a skip, or a failure under --strict.
const SECTION := "require"

func run(t) -> void:
	t.check("existing_tool", t.require_tool(t.python(), "the tooling Python"))
	if t.require_tool("tt-selftest-no-such-tool", "probe check"):
		t.check("MISSING_TOOL_MUST_NOT_PASS", false)
