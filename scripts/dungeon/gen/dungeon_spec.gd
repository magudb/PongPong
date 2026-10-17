class_name DungeonSpec
extends RefCounted
## Layout-relevant data only. This library is safe to call from worker threads.
const BORDER := 3

## cfg = GameData.cfg("dungeon"); returns the generator spec of floor n (ints, strings, Arrays, Dictionaries only).
static func spec_for(cfg: Dictionary, n: int) -> Dictionary:
	var floors: Array = cfg.get("floors", []) as Array
	var rec: Dictionary = {}
	for f in floors:
		if int((f as Dictionary).get("n", 0)) == n:
			rec = f as Dictionary
	if rec.is_empty(): return {}
	var band_id: String = str(rec.get("band", "skovkant"))
	var band: Dictionary = (cfg.get("bands", {}) as Dictionary).get(band_id, {}) as Dictionary
	var terr: Dictionary = band.get("terrain", {}) as Dictionary
	var mix: Dictionary = band.get("enemy_mix", {}) as Dictionary
	var spots: Array = array_of(rec.get("spots", []))
	var anchors: Array = array_of(rec.get("anchors", []))
	var nook_anchor_count: int = 0
	for a in anchors:
		if str((a as Dictionary).get("place", "")) == "nook":
			nook_anchor_count += int((a as Dictionary).get("count", 1))
	var nook_main: bool = bool(rec.get("nook_main", false))
	var w: int = int(rec.get("w", 64))
	var h: int = int(rec.get("h", 48))
	var cols: int = maxi(3, (w - 2 * (BORDER + 3) + 5) / 14)
	var rows: int = maxi(2, (h - 2 * (BORDER + 3) + 5) / 17)
	return {
		"w": w, "h": h, "floor": n, "band": band_id, "tier": int(band.get("enemy_tier", 1)),
		"boss": str(rec.get("boss", "")) != "", "boss_kind": str(rec.get("boss", "")), "boss_adds": int(rec.get("boss_adds", 0)), "hulen": bool(rec.get("hulen", true)), "stone": bool(rec.get("stone", false)),
		"ponds": int(rec.get("ponds", 0)), "glow": int(rec.get("glow", 0)), "digs": int(rec.get("digs", 0)),
		"enemies": int(rec.get("enemies", 0)), "ambush": int(rec.get("ambush", 0)), "critters": int(rec.get("critters", 0)),
		"inner_crowns": int(rec.get("inner_crowns", 0)), "nook_main": nook_main, "lake": str(rec.get("lake", "")),
		"whispers": int(rec.get("whispers", 0)), "nodes": rec.get("nodes", {}) as Dictionary, "spots": spots, "anchors": anchors,
		"chest_tier": str(band.get("chest_tier", "trae")), "enemy_mix": mix,
		"terrain": {"floor": str(terr.get("floor", "m")), "patch": str(terr.get("patch", "g")), "path": str(terr.get("path", "p"))},
		"nooks": spots.size() + nook_anchor_count + (1 if nook_main else 0),
		"lights_max": int((cfg.get("limits", {}) as Dictionary).get("lights_max", 10)),
		"min_sites": maxi(4, cols * rows * 55 / 100), "min_walk_pct": int((cfg.get("limits", {}) as Dictionary).get("walk_share_min_pct", 14)),
		"max_walk_pct": int((cfg.get("limits", {}) as Dictionary).get("walk_share_max_pct", 34)),
		"hard_nodes": array_of(cfg.get("hard_nodes", [])),
		"fallback_seed": _fallback_seed(cfg, n),
	}


static func array_of(v: Variant) -> Array:
	return v as Array if v is Array else []


## cfg.seed.fallback = a positional list of 12 pinned seeds (floor n -> entry n - 1); 0 = none
static func _fallback_seed(cfg: Dictionary, n: int) -> int:
	var sd: Dictionary = cfg.get("seed", {}) as Dictionary
	var lst: Array = array_of(sd.get("fallback", []))
	return int(lst[n - 1]) if n >= 1 and n <= lst.size() else 0


static func spec_hash(cfg: Dictionary) -> String:
	var value := 0x811C9DC5
	for section in ["floors","bands","rim","limits"]:
		for byte in JSON.stringify(cfg.get(section,{}),"",true).to_utf8_buffer():
			value = ((value ^ byte) * 16777619) & 0xFFFFFFFF
	return "%08x" % value
