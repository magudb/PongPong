extends RefCounted
## Harness self-test: t.perf_ok() keeps the native reference, allows TT_PERF_SCALE (clamped to 1..4) on top of it and records
## the timings that passed only through that allowance (SLOW lines). selftest_harness.sh runs it with several scales.
const SECTION := "perf"

func run(t) -> void:
	t.check("within_reference", t.perf_ok("fast", 1.0, 2.0))
	t.check("inside_allowance", t.perf_ok("slow", 3.0, 2.0))
	# 20 is past OVERLOAD_CEILING x every limit below (4, 8): judged even when the gate loads this machine (t.not_judged)
	t.check("over_limit_is_false", not t.perf_ok("over", 20.0, 2.0))
