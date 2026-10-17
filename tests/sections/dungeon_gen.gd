extends RefCounted
const SECTION := "dungeon_gen"
const TIMEOUT_S := 180.0
const GOLDEN := ["ea020e8c","245477a0","d7940510","0bb780e0","6e06f71d","2548c06e","b48ceefc","b7ab3ea1","34d1d0b6","a8f88b52","c9f4afaa","ebb30a85"]
func run(t) -> void:
	var cfg := LuaData.dict(Svc.lua_config("dungeon",{}))
	_rng(t)
	t.check("spec.floor_table_valid",cfg.get("max_floor") == 12 and LuaData.arr(cfg.get("floors")).size() == 12 and DungeonSpec.spec_for(cfg,13).is_empty())
	t.check("spec.rim_wall_depth_zero_and_twelve_fallback_seeds_listed",int(cfg.rim.wall_depth) == 0 and LuaData.arr(cfg.seed.fallback).size() == 12)
	var gen := DungeonGen.new()
	var tally := {"checks":{},"bad":{},"first":{}}
	var attempts := 0
	var first := 0
	var fallbacks := 0
	var moonstone := 0
	for floor_number in range(1,13):
		var spec := DungeonSpec.spec_for(cfg,floor_number)
		moonstone += int(spec.nodes.get("moonstone",0))
		var digest := 0x811C9DC5
		for i in 20:
			var seed_value := DungeonRng.hash_key("stress",i+1,floor_number)
			var floor_data := gen.generate(seed_value,spec)
			t.check("gen.generation_succeeded_f%d_%d" % [floor_number,i],bool(floor_data.stats.get("ok",false)))
			if not floor_data.stats.get("ok",false): continue
			attempts += floor_data.attempts
			if floor_data.attempts == 1: first += 1
			if floor_data.stats.get("fallback",false): fallbacks += 1
			var ctx := _context(floor_number,seed_value,i+1)
			var exported := DungeonExport.build(floor_data,cfg,ctx)
			var parsed := AreaMap.parse_text(exported.text)
			tally["tag"] = "floor %d seed %d" % [floor_number,seed_value]
			DungeonVerify.verify(parsed,spec,cfg,ctx,tally)
			if i < 10: digest = ((digest ^ _hash(exported.text)) * 16777619) & 0xFFFFFFFF
			if i == 0:
				var repeated := DungeonExport.build(gen.generate(seed_value,spec),cfg,ctx)
				t.check("gen.same_seed_same_text_f%d" % floor_number,exported.text == repeated.text)
				var changed := DungeonGen.build_text(cfg,floor_number,DungeonRng.hash_key("different",i+1,floor_number),ctx)
				t.check("gen.save_changes_layout_f%d" % floor_number,changed.ok and changed.text != exported.text)
			t.check("gen.export_budget_f%d_%d" % [floor_number,i],int(exported.stats.chars_used) <= DungeonExport.POOL.length())
		t.check("gen.golden_digest_f%d" % floor_number,"%08x" % digest == GOLDEN[floor_number-1],"%08x" % digest)
		var a := gen.generate(1,spec,0)
		var b := gen.generate(999,spec,0)
		t.check("gen.fallback_valid_f%d" % floor_number,a.stats.get("ok",false) and a.stats.get("fallback",false) and gen.digest(a) == gen.digest(b))
		var ctx := _context(floor_number,1,1)
		if a.stats.get("ok",false): DungeonVerify.verify(AreaMap.parse_text(DungeonExport.build(a,cfg,ctx).text),spec,cfg,ctx,tally)
	for name in tally.checks:
		t.check("gen.inv."+str(name),not tally.bad.has(name),str(tally.first.get(name,"")))
	t.check("spec.moonstone_supply_8",moonstone >= 8)
	t.check("gen.invariants_on_240_floors",tally.bad.is_empty(),str(tally.first))
	t.check("gen.first_attempt_rate",float(first)/240.0 >= 0.85,"%d/240" % first)
	t.check("gen.mean_attempts",float(attempts)/240.0 <= 1.3,str(float(attempts)/240.0))
	t.check("gen.fallback_rate_under_1_in_2000",fallbacks == 0,str(fallbacks))
	for regression in [[1,1550,3779965653854282429],[2,1396,1116886881598385135],[2,1526,4411067925445533764]]:
		var spec := DungeonSpec.spec_for(cfg,regression[0])
		var floor_data := gen.generate(regression[2],spec)
		var ctx := _context(regression[0],regression[2],regression[1]+1)
		var checks := {"checks":{},"bad":{},"first":{}}
		if floor_data.stats.get("ok",false): DungeonVerify.verify(AreaMap.parse_text(DungeonExport.build(floor_data,cfg,ctx).text),spec,cfg,ctx,checks)
		t.check("gen.regression_seed_%d" % regression[1],floor_data.stats.get("ok",false) and checks.bad.is_empty(),str(checks.first))
		if regression[1] == 1396: t.check("gen.fallback_used_on_regression_seed",floor_data.stats.get("fallback",false))
	var ctx := _context(3,42,1)
	var serial := DungeonGen.build_text(cfg,3,42,ctx)
	var box := {}
	var task := WorkerThreadPool.add_task(func(): box["result"] = DungeonGen.build_text(cfg,3,42,ctx))
	WorkerThreadPool.wait_for_task_completion(task)
	t.check("gen.thread_matches_serial",serial.ok and box.result.ok and box.result.text == serial.text)
	t.check("gen.rejects_unknown_floor_without_scene_errors",not DungeonGen.build_text(cfg,0,1).ok)
	var iso_ctx := _context(1,42,1)
	iso_ctx["projection"] = "iso"
	var iso := DungeonGen.build_text(cfg,1,42,iso_ctx)
	var iso_map := AreaMap.parse_text(iso.text)
	t.check("export.iso_projection_builds",iso.ok and iso_map.errors.is_empty() and iso_map.projection == &"iso")
	_alt_table(t,cfg)
	for locale in ["da","en"]:
		TranslationServer.set_locale(locale)
		for key in ["DUNGEON_WHISPER_SKOVKANT_1","DUNGEON_PROMPT_GLOWING","DUNGEON_LEAVE","DUNGEON_LEAVE_CONFIRM","DUNGEON_RUN_RESET","DUNGEON_FLOOR_FMT","RUNE_ACTIVATED","RUNE_REST","RUNE_PROMPT","RUNE_PICKER_TITLE","RUNE_PICKER_START","RUNE_PICKER_FLOOR_FMT","HULEN_ROOTS_PART"]:
			t.check("keys_defined_%s_%s" % [locale,key],TranslationServer.translate(key) != key)
	TranslationServer.set_locale("da")
func _alt_table(t, source: Dictionary) -> void:
	var cfg := source.duplicate(true)
	for row in cfg.floors:
		row["boss"] = "snurresvamp" if int(row.n) % 3 == 0 else ""
		row["boss_adds"] = 4 if int(row.n) % 3 == 0 else 0
		row["stone"] = true
	# No production fallbacks apply after changing a floor's spec.
	cfg.seed["fallback"] = []
	var tally := {"checks":{},"bad":{},"first":{}}
	var failed := []
	for n in range(1,13):
		var spec := DungeonSpec.spec_for(cfg,n)
		for i in 10:
			var seed_value := DungeonRng.hash_key("alt-table",i+1,n)
			var result := DungeonGen.build_text(cfg,n,seed_value,_context(n,seed_value,i+1))
			if not result.ok:
				failed.append([n,i])
				continue
			DungeonVerify.verify(AreaMap.parse_text(result.text),spec,cfg,_context(n,seed_value,i+1),tally)
	t.check("gen.alt_table_boss_3_6_9_12_valid",failed.is_empty() and tally.bad.is_empty(),str({"failed":failed,"invariants":tally.first}))
func _rng(t) -> void:
	var vectors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/dungeon/rng_vectors.json"))
	for stream in vectors.streams:
		var rng := DungeonRng.new(int(stream.seed))
		var actual: Array = []
		for _i in 8: actual.append("%08x" % rng.next_u32())
		t.check("rng.sfc32_vectors_pinned_"+str(stream.seed),actual == stream.values,str(actual))
	for row in vectors.hashes:
		t.check("rng.hash_key_pinned_"+str(row.save)+"_"+str(row.floor),DungeonRng.hash_key(row.save,int(row.day),int(row.floor)) == int(row.value))
	var rng := DungeonRng.new(42)
	var counts := [0,0,0,0,0,0,0]
	for _i in 70000: counts[rng.below(7)] += 1
	t.check("rng.below_unbiased",counts.all(func(n): return absi(n-10000) < 450),str(counts))
	var flips := 0
	for day in 100:
		var diff := DungeonRng.hash_key("a",day,1) ^ DungeonRng.hash_key("a",day+1,1)
		for bit in 62: flips += (diff >> bit) & 1
	t.check("rng.hash_key_avalanche",flips > 2800 and flips < 3400,str(flips))
func _context(floor_number: int, seed_value: int, day: int) -> Dictionary:
	return {"next_id":"moerkeskoven_f%d" % (floor_number+1),"prev_id":"moerkeskoven_f%d" % (floor_number-1),"day":day,"seed_text":str(seed_value),"gen_version":1,"spec_hash":"0"}
func _hash(text: String) -> int:
	var value := 0x811C9DC5
	for byte in text.to_utf8_buffer(): value = ((value ^ byte) * 16777619) & 0xFFFFFFFF
	return value
