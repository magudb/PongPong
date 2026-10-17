extends SceneTree
## DESIGNER A prototype: stress driver. user args: first=<i> count=<n> floors=<1,2,..|all> [world=<text>] [det=1]
## For floor f and index i: seed = hash_key(world, day = 1 + i, f). Generates, exports, parses and verifies every floor and prints a tally.
const Gen := preload("res://scripts/dungeon/gen/dungeon_gen.gd")
const Rng := preload("res://scripts/dungeon/gen/dungeon_rng.gd")
const Export := preload("res://scripts/dungeon/gen/dungeon_export.gd")
const Verify := preload("res://scripts/dungeon/gen/dungeon_verify.gd")


func _initialize() -> void:
	await process_frame
	var args: Dictionary = {}
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = str(a).split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var first: int = int(args.get("first", 0))
	var count: int = int(args.get("count", 100))
	var world: String = str(args.get("world", "stress"))
	var cfg: Dictionary = GameData.cfg("dungeon", {}) as Dictionary
	var floors: Array = []
	if str(args.get("floors", "all")) == "all":
		for n in range(1, int(cfg.get("max_floor", 12)) + 1):
			floors.append(n)
	else:
		for s in str(args["floors"]).split(",", false):
			floors.append(int(s))
	var gen = Gen.new()
	var T: Dictionary = {"checks": {}, "bad": {}, "first": {}}
	var attempts_hist: Dictionary = {}
	var fail_reasons: Dictionary = {}
	var per_floor_ms: Dictionary = {}
	var export_ms: Dictionary = {}
	var verify_ms: Dictionary = {}
	var t_all: int = Time.get_ticks_usec()
	var n_floors: int = 0
	var gen_failed: int = 0
	var fallback_used: int = 0
	var det_bad: int = 0
	var sizes: Dictionary = {}
	var digest_of: Dictionary = {}
	var phase_sum: Dictionary = {}
	var phase_n: Dictionary = {}
	for f in floors:
		var spec: Dictionary = Gen.spec_for(cfg, int(f))
		per_floor_ms[f] = []
		export_ms[f] = []
		verify_ms[f] = []
		for i in range(first, first + count):
			var seed_value: int = Rng.hash_key(world, 1 + i, int(f))
			var t0: int = Time.get_ticks_usec()
			var fl = gen.generate(seed_value, spec)
			var t1: int = Time.get_ticks_usec()
			attempts_hist[fl.attempts] = int(attempts_hist.get(fl.attempts, 0)) + 1
			if bool(fl.stats.get("fallback", false)):
				fallback_used += 1
				print("FALLBACK-USED f%d i%d seed %d (all %d attempts failed, first_fail %s): pinned seed %d" % [int(f), i, seed_value, fl.attempts - 1, fl.first_fail, int(spec.get("fallback_seed", 0))])
			if fl.first_fail != "":
				fail_reasons[fl.first_fail] = int(fail_reasons.get(fl.first_fail, 0)) + 1
			if not bool(fl.stats.get("ok", false)):
				gen_failed += 1
				print("GENFAIL f%d i%d seed %d attempts %d first_fail %s last_fail %s" % [int(f), i, seed_value, fl.attempts, fl.first_fail, str(fl.stats.get("fail", "?"))])
				continue
			var ctx: Dictionary = {"next_id": "moerkeskoven_f%d" % (int(f) + 1), "prev_id": "moerkeskoven_f%d" % (int(f) - 1), "day": 1 + i, "seed_text": str(seed_value), "gen_version": 1, "spec_hash": "0"}
			var ex: Dictionary = Export.build(fl, cfg, ctx)
			var t2: int = Time.get_ticks_usec()
			var m: AreaMap = AreaMap.parse_text(ex["text"])
			T["tag"] = "f%d i%d seed %d" % [int(f), i, seed_value]
			Verify.verify(m, spec, cfg, ctx, T)
			var t3: int = Time.get_ticks_usec()
			if n_floors % 500 == 0: print("PROGRESS floor %d index %d verified %d" % [int(f),i,n_floors])
			if not phase_sum.has(f):
				phase_sum[f] = [0, 0, 0, 0, 0, 0, 0, 0]
				phase_n[f] = 0
			if fl.phase_us.size() == 8:
				for pi in 8:
					phase_sum[f][pi] += int(fl.phase_us[pi])
				phase_n[f] = int(phase_n[f]) + 1
			(per_floor_ms[f] as Array).append((t1 - t0) / 1000.0)
			(export_ms[f] as Array).append((t2 - t1) / 1000.0)
			(verify_ms[f] as Array).append((t3 - t2) / 1000.0)
			n_floors += 1
			sizes[f] = ex["stats"]
			if str(args.get("digest", "0")) == "1":
				var hh: int = 0x811C9DC5
				for b in (ex["text"] as String).to_utf8_buffer():
					hh = ((hh ^ b) * 16777619) & 0xFFFFFFFF
				digest_of[f] = ((int(digest_of.get(f, 0x811C9DC5)) ^ hh) * 16777619) & 0xFFFFFFFF
			if str(args.get("det", "0")) == "1" and i % 7 == 0:
				var fl2 = gen.generate(seed_value, spec)
				var ex2: Dictionary = Export.build(fl2, cfg, ctx)
				if str(ex2["text"]) != str(ex["text"]):
					det_bad += 1
				T["stat_det_checked"] = int(T.get("stat_det_checked", 0)) + 1
	var total_ms: float = (Time.get_ticks_usec() - t_all) / 1000.0
	if str(args.get("digest", "0")) == "1":
		var parts: Array = []
		for f in floors:
			parts.append("f%d=%08x" % [int(f), int(digest_of.get(f, 0))])
		print("DIGEST arch=%s count=%d first=%d %s" % [OS.get_name() + "/" + Engine.get_architecture_name(), count, first, " ".join(parts)])
	if str(args.get("seeds", "0")) == "1":
		var d: Dictionary = {}
		var sp: Dictionary = Gen.spec_for(cfg, 3)
		for day in 40:
			var fl3 = gen.generate(Rng.hash_key("A", day + 1, 3), sp)
			d[gen.digest(fl3)] = true
		var d2: Dictionary = {}
		for w in 40:
			var fl4 = gen.generate(Rng.hash_key("save%d" % w, 5, 3), sp)
			d2[gen.digest(fl4)] = true
		var d3: Dictionary = {}
		for f in range(1, 13):
			var fl5 = gen.generate(Rng.hash_key("A", 5, f), Gen.spec_for(cfg, f))
			d3[gen.digest(fl5)] = true
		print("SEEDS 40 consecutive days -> %d distinct floors; 40 world seeds -> %d distinct; 12 floors of one day -> %d distinct" % [d.size(), d2.size(), d3.size()])
	print("STRESS floors_verified=%d gen_failed=%d fallback_used=%d total_ms=%.0f" % [n_floors, gen_failed, fallback_used, total_ms])
	print("STRESS attempts_hist=%s first_fail=%s" % [str(attempts_hist), str(fail_reasons)])
	# the retry loop can hide a broken generator: the first-attempt rate and the mean attempts are invariants too (floors 1-2 are small, so the bar is on the whole run)
	var n_all: int = 0
	var att_sum: int = 0
	for a in attempts_hist:
		n_all += int(attempts_hist[a])
		att_sum += int(a) * int(attempts_hist[a])
	if n_all >= 100 and floors.size() >= 6:
		Verify._ok(T, "first_attempt_rate_at_least_85_percent", int(attempts_hist.get(1, 0)) * 100 >= n_all * 85, "%d of %d" % [int(attempts_hist.get(1, 0)), n_all])
		Verify._ok(T, "mean_attempts_at_most_1.3", att_sum * 10 <= n_all * 13, "%d attempts for %d floors" % [att_sum, n_all])
	var names: Array = (T["checks"] as Dictionary).keys()
	names.sort()
	var bad_total: int = 0
	for k in names:
		var v: int = int((T["bad"] as Dictionary).get(k, 0))
		bad_total += v
		print("INV %-56s checks %6d violations %d%s" % [k, (T["checks"] as Dictionary)[k], v, ("   first: " + str((T["first"] as Dictionary)[k])) if v > 0 else ""])
	print("INV TOTAL violations: %d (determinism mismatches %d of %d)" % [bad_total, det_bad, int(T.get("stat_det_checked", 0))])
	print("STAT enemy_budget_exact %d of %d floors; walkable share mean %.1f %%; route spawn->Hulen mean %.1f cells; props max %d (in view max %d); rim crowns mean %.1f max %d; wall window max %d" % [
		int(T.get("stat_enemy_exact", 0)), int(T.get("stat_floors", 0)), float(T.get("stat_walk_pct_sum", 0)) / maxf(1.0, float(T.get("stat_floors", 1))) / 10.0,
		float(T.get("stat_route_sum", 0)) / maxf(1.0, float(T.get("stat_route_n", 1))), int(T.get("stat_props_max", 0)), int(T.get("stat_props_view_max", 0)), float(T.get("stat_rim_sum", 0)) / maxf(1.0, float(T.get("stat_floors", 1))), int(T.get("stat_rim_max", 0)), int(T.get("stat_wall_window_max", 0))])
	for f in floors:
		var g: Array = per_floor_ms.get(f, []) as Array
		if g.is_empty():
			continue
		print("TIME floor %2d (%dx%d): gen %s | export %s | verify %s   export stats %s" % [f, int(Gen.spec_for(cfg, int(f))["w"]), int(Gen.spec_for(cfg, int(f))["h"]), _q(g), _q(export_ms[f]), _q(verify_ms[f]), str(sizes.get(f, {}))])
	for f in floors:
		if phase_n.has(f) and int(phase_n[f]) > 0:
			var ps: Array = []
			for pi in 8:
				ps.append("%.2f" % (float(phase_sum[f][pi]) / float(phase_n[f]) / 1000.0))
			print("PHASE floor %2d (last attempt, mean ms): sites+clearings %s | graph %s | trails+ponds %s | repair %s | nooks %s | features %s | inner crowns+decor+repair %s | validate %s" % [f, ps[0], ps[1], ps[2], ps[3], ps[4], ps[5], ps[6], ps[7]])
	quit(1 if bad_total > 0 or det_bad > 0 or gen_failed > 0 else 0)


func _q(a: Array) -> String:
	var s: Array = a.duplicate()
	s.sort()
	var n: int = s.size()
	if n == 0:
		return "-"
	var mean: float = 0.0
	for v in s:
		mean += float(v)
	mean /= n
	return "mean %.1f p50 %.1f p95 %.1f p99 %.1f max %.1f" % [mean, s[n / 2], s[mini(n - 1, n * 95 / 100)], s[mini(n - 1, n * 99 / 100)], s[n - 1]]
