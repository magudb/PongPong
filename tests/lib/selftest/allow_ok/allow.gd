extends RefCounted
## Harness self-test: t.allow() declares expected warnings/errors; the run passes and counts them as allowed.
const SECTION := "allow"

func run(t) -> void:
	t.allow("EXPECTED-WARNING")
	t.allow("EXPECTED-ERROR")
	push_warning("EXPECTED-WARNING number one")
	push_warning("EXPECTED-WARNING number two")
	push_error("EXPECTED-ERROR once")
	await t.frames(2)
	t.expect_eq(t.allowed_count("EXPECTED-WARNING"), 2, "both warnings were seen and allowed")
	t.expect_allowed("EXPECTED-ERROR", 1, "the allowed error really happened")
	var mark: int = t.log_mark()
	push_warning("EXPECTED-WARNING three")
	t.expect_clean_since(mark, "allowed messages do not count as new engine messages")
