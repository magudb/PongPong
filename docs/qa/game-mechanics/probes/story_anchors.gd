extends RefCounted
## Check mandatory story witnesses against deterministic generated layouts.
const SECTION := "story_anchors"
const TIMEOUT_S := 180.0

func run(t) -> void:
	var cfg := LuaData.dict(Svc.lua_config("dungeon", {}))
	var observations: Array = []
	var missing: Array = []
	for number in [2, 6, 10]:
		for index in 40:
			var seed_value := DungeonRng.hash_key("mechanics-review", index + 1, number)
			var context := {"day": 1, "seed_text": str(seed_value)}
			var result := DungeonGen.build_text(cfg, number, seed_value, context)
			t.check("generated_f%d_sample_%d" % [number, index], bool(result.get("ok", false)))
			if not bool(result.get("ok", false)): continue
			var map := AreaMap.parse_text(str(result.text))
			var keepers := 0
			for y in map.height:
				for x in map.width:
					var ch := str(map.objects[y]).substr(x, 1)
					if str(map.markers.get(ch, {}).get("marker", "")) == "hulen_keeper": keepers += 1
			var row := {"floor": number, "sample": index, "seed": str(seed_value), "keepers": keepers}
			observations.append(row)
			if keepers == 0:
				var tally := {"checks": {}, "bad": {}, "first": {}}
				DungeonVerify.verify(map, DungeonSpec.spec_for(cfg, number), cfg, context, tally)
				row["independent_verifier_failures"] = tally.bad
				t.check("independent_verifier_accepts_missing_witness_f%d_%d" % [number, index], tally.bad.is_empty(), str(tally.first))
				missing.append(row)
				if missing.size() == 1:
					var example := FileAccess.open("res://docs/qa/game-mechanics/missing-witness.map", FileAccess.WRITE)
					if example != null: example.store_string(str(result.text))
			await t.frames(1)
	var file := FileAccess.open("res://docs/qa/game-mechanics/story-anchors.json", FileAccess.WRITE)
	t.check("observations_written", file != null)
	if file != null: file.store_string(JSON.stringify({"base_commit": "abec447", "samples": observations, "missing": missing}, "\t") + "\n")
	print("  info  witness anchors missing in %d / %d deterministic layouts" % [missing.size(), observations.size()])
