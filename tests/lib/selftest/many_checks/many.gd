extends RefCounted
## Harness self-test: a section with thousands of checks (the lock-step wardrobe test has >= 8,960) must not flood
## the log: only the first 400 ok lines are printed, every failure always is, and all checks are counted.
const SECTION := "many"

func run(t) -> void:
	for i in 1500:
		t.expect(i >= 0, "ok line number %d" % i)
	t.expect(false, "FAILURES-ARE-ALWAYS-PRINTED")
