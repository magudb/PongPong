extends SceneTree
## EDITOR'S FINAL PASS: tools/dungeon/find_fallback_seeds (prototype).  For every floor of the table it walks the FIXED sequence seed_k = hash_key("fallback", 1, floor * 1024 + k), k = 0, 1, 2 ...
## and pins the first seed whose ONE ordinary attempt passes the generator's own validation AND the independent verifier with 0 violations (export -> AreaMap.parse_text -> DungeonVerify).
## Prints the Lua list for dungeon.lua `seed.fallback` (positional, floor 1 first).  user args: tries=<max k per floor, default 64>
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
	var tries: int = int(args.get("tries", 64))
	var cfg: Dictionary = GameData.cfg("dungeon", {}) as Dictionary
	var gen = Gen.new()
	var picked: Array = []
	for f in range(1, int(cfg.get("max_floor", 12)) + 1):
		var spec: Dictionary = Gen.spec_for(cfg, f)
		spec["fallback_seed"] = 0
		var found: int = 0
		var n_ok_attempt: int = 0
		var n_clean: int = 0
		for k in tries:
			var seed_value: int = Rng.hash_key("fallback", 1, f * 1024 + k)
			var fl = gen.generate(seed_value, spec, 1)
			if not bool(fl.stats.get("ok", false)):
				continue
			n_ok_attempt += 1
			var ctx: Dictionary = {"next_id": "moerkeskoven_f%d" % (f + 1), "prev_id": "moerkeskoven_f%d" % (f - 1), "day": 1, "seed_text": str(seed_value), "gen_version": 1, "spec_hash": "0"}
			var ex: Dictionary = Export.build(fl, cfg, ctx)
			var m: AreaMap = AreaMap.parse_text(ex["text"])
			var T: Dictionary = {"checks": {}, "bad": {}, "first": {}, "tag": "f%d k%d" % [f, k]}
			Verify.verify(m, spec, cfg, ctx, T)
			var bad: int = 0
			for v in (T["bad"] as Dictionary).values():
				bad += int(v)
			if bad == 0:
				n_clean += 1
				if found == 0:
					found = seed_value
					print("FALLBACK f%d k=%d seed %d  (digest %08x)" % [f, k, seed_value, gen.digest(fl)])
		print("FALLBACK-STAT f%d first-attempt-ok %d of %d, verifier-clean %d" % [f, n_ok_attempt, tries, n_clean])
		picked.append(found)
	var parts: Array = []
	for s in picked:
		parts.append(str(s))
	print("LUA seed.fallback = { %s }" % ", ".join(parts))
	quit(0)
