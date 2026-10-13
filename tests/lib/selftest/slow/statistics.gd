extends RefCounted
## Harness self-test: sections may run for statistical work up to (and beyond) 30 s without any special declaration
## (default watchdog 120 s). Only run with tools/dev/selftest_harness.sh --with-slow (takes ~35 s).
const SECTION := "statistics"

func run(t) -> void:
	var hits := 0
	for round_no in 35:
		for i in 1000:
			if t.rng.randf() < 0.12:
				hits += 1
		await t.seconds(1.0)
	t.check("ran_longer_than_30_seconds", true, "35 rounds of 1000 seeded draws, %d hits (expected about 4200)" % hits)
	t.expect_near(float(hits) / 35000.0, 0.12, 0.01, "seeded statistics land near the odds")
