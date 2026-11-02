extends RefCounted
## Pure LC2 codec and receipt reducer. Only the fixed seven-day mining source
## uses day as occurrence authority; detail retention is NOT dedup authority.
const VERSION := 4
const SOURCE := "dark_forest_mining/return_to_smith"
const NPC := "smith_thorin"
const PLAYERS := ["p0", "p1", "p2", "p3"]
const MAX_MEMORIES := 16
const DETAIL_TTL := 28
const MAX_BYTES := 262144
const MAX_DAY := 2147483647

static func empty() -> Dictionary:
	return {"v": VERSION, "world": {"pairs": {}}, "players": {}, "orphans": {"players": {}}}

static func context(state: Dictionary, npc: String, player_id: StringName, day: int) -> Dictionary:
	if str(player_id) not in PLAYERS:
		return {}
	var row: Dictionary = state.get("players", {}).get(str(player_id), {}).get("npcs", {}).get(npc, {})
	if row.is_empty():
		return {}
	var out := row.duplicate(true)
	out["memories"] = out.get("memories", []).filter(func(m): return int(m.day) <= day and day - int(m.day) < DETAIL_TTL)
	return out

static func record(state: Dictionary, player_id: StringName, npc: String, day: int) -> Dictionary:
	if str(player_id) not in PLAYERS or npc != NPC or day < 1 or day > MAX_DAY:
		return {"ok": false, "reason": "invalid_receipt"}
	var players: Dictionary = state.players
	var player: Dictionary = players.get(str(player_id), {"npcs": {}})
	var row: Dictionary = player.npcs.get(npc, {"memories": [], "source_watermarks": {}})
	if day <= int(row.source_watermarks.get(SOURCE, 0)):
		return {"ok": false, "reason": "duplicate"}
	var memories: Array = row.memories.filter(func(m): return int(m.day) <= day and day - int(m.day) < DETAIL_TTL)
	var event_id := _event(str(player_id), day)
	memories.append({"event_id": event_id, "kind": "helped_smith", "day": day, "source": SOURCE, "subject": NPC, "visibility": "private"})
	while memories.size() > MAX_MEMORIES:
		memories.pop_front()
	row.memories = memories
	row.source_watermarks[SOURCE] = day
	player.npcs[npc] = row
	players[str(player_id)] = player
	# Preserve the original LC2 receipt range. The optional selector's tighter
	# day range must not corrupt/refuse a valid private save beyond its horizon.
	if day > 1000000:
		return {"ok": true, "event_id": event_id}
	# Shared knowledge belongs to the recipient, not to an ambient player.
	# Only this validated source reducer creates it; v1 migration never scans
	# private memories to invent a new pending cause. No player payload escapes.
	var pilot: Dictionary = state.world.get("pilot", {"selected": {}, "cooldowns": {}})
	pilot["pending_day"] = maxi(day, int(pilot.get("pending_day", 0)))
	state.world["pilot"] = pilot
	return {"ok": true, "event_id": event_id}

static func _event(pid: String, day: int) -> String:
	return "%s:%s:%d" % [SOURCE, pid, day]

## Validate without copying untrusted trees first. Closed vocabulary in this
## tracer bullet: private v1 receipts migrate without inferred shared knowledge.
static func decode(raw: Variant, known: Dictionary, day: int = 0) -> Dictionary:
	if not _bounded_json(raw) or not raw is Dictionary:
		return {"ok": false}
	if not _whole(raw.get("v"), 1, VERSION) or not _keys(raw, ["v", "world", "players", "orphans", "responses", "encounters"]):
		return {"ok": false}
	var world: Variant = raw.get("world", {})
	var orphans: Variant = raw.get("orphans", {})
	if not world is Dictionary or not _keys(world, ["pairs", "pilot", "citizens"]) or not world.get("pairs", {}) is Dictionary :
		return {"ok": false}
	if not orphans is Dictionary or not _keys(orphans, ["players", "pilot", "citizens", "encounters"]) or JSON.stringify(orphans).to_utf8_buffer().size() > 65536:
		return {"ok": false}
	var active := _decode_players(raw.get("players", {}), day)
	var suspended := _decode_players(orphans.get("players", {}), day)
	if not active.ok or not suspended.ok:
		return {"ok": false}
	var out := empty()
	var encounters: Dictionary = Svc.static_call("res://scripts/social/living/living_cast.gd", &"decode_encounters", [raw.get("encounters", {})], {"ok": false})
	if not encounters.get("ok", false) or (int(raw.v) < 4 and not encounters.rows.is_empty()): return {"ok": false}
	var retired_encounters: Dictionary = Svc.static_call("res://scripts/social/living/living_cast.gd", &"decode_encounters", [orphans.get("encounters", {})], {"ok": false})
	if not retired_encounters.get("ok", false) or (int(raw.v) < 4 and not retired_encounters.rows.is_empty()): return {"ok": false}
	var merged: Dictionary = _merge_encounters(encounters.rows, retired_encounters.rows)
	for pid in merged:
		for npc in merged[pid]:
			var key := "encounters"
			var bucket: Dictionary = out if known.has(npc) else out.orphans
			if not bucket.has(key): bucket[key] = {}
			if not bucket[key].has(pid): bucket[key][pid] = {}
			bucket[key][pid][npc] = merged[pid][npc]
	var citizens: Dictionary = Svc.static_call("res://scripts/social/living/living_actions.gd", &"decode", [world.get("citizens", {})], {"ok": false})
	var retired_citizens: Dictionary = Svc.static_call("res://scripts/social/living/living_actions.gd", &"decode", [orphans.get("citizens", {})], {"ok": false})
	if not citizens.get("ok", false) or not retired_citizens.get("ok", false): return {"ok": false}
	if int(raw.v) < 4 and (not citizens.rows.is_empty() or not retired_citizens.rows.is_empty()): return {"ok": false}
	for npc in retired_citizens.rows:
		var old: Dictionary = citizens.rows.get(npc, {})
		var retired: Dictionary = retired_citizens.rows[npc]
		if int(retired.day) > int(old.get("day", 0)) or (retired.day == old.get("day") and retired.closed_day > old.get("closed_day", 0)): citizens.rows[npc] = retired
	for npc in citizens.rows:
		var bucket: Dictionary = out.world if known.has(npc) else out.orphans
		if not bucket.has("citizens"): bucket["citizens"] = {}
		bucket.citizens[npc] = citizens.rows[npc]
	var responses: Dictionary = Svc.static_call("res://scripts/social/living/living_pair.gd", &"decode_responses", [raw.get("responses", {})], {"ok": false})
	if not responses.get("ok", false) or (int(raw.v) < 3 and not responses.rows.is_empty()): return {"ok": false}
	if not responses.rows.is_empty(): out["responses"] = responses.rows
	var pairs: Dictionary = Svc.static_call("res://scripts/social/living/living_pair.gd", &"decode", [world.get("pairs", {})], {"ok": false})
	if not pairs.get("ok", false) or (int(raw.v) < 3 and not pairs.pairs.is_empty()): return {"ok": false}
	if not pairs.pairs.is_empty():
		# Retired pilot members suspend the whole incident; preserve its terminal.
		out.world.pairs = pairs.pairs
	if int(raw.v) == 1 and (world.has("pilot") or orphans.has("pilot")):
		return {"ok": false}
	var pilot: Dictionary = Svc.static_call("res://scripts/social/living/living_activity.gd", &"decode", [world.get("pilot", {}), orphans.get("pilot", {})], {"ok": false})
	if not pilot.get("ok", false):
		return {"ok": false}
	if not pilot.row.is_empty():
		if known.has(NPC): out.world["pilot"] = pilot.row
		else: out.orphans["pilot"] = pilot.row
	for pid in PLAYERS:
		var row: Dictionary = active.rows.get(pid, {}).get("npcs", {}).get(NPC, {})
		var orphan: Dictionary = suspended.rows.get(pid, {}).get("npcs", {}).get(NPC, {})
		# Content reappearance cannot regress dedup authority if both buckets
		# contain the same row. Keep the higher source watermark deterministically.
		if int(orphan.get("source_watermarks", {}).get(SOURCE, 0)) > int(row.get("source_watermarks", {}).get(SOURCE, 0)):
			row = orphan
		if not row.is_empty():
			var bucket: Dictionary = out.players if known.has(NPC) else out.orphans.players
			bucket[pid] = {"npcs": {NPC: row}}
	if JSON.stringify(out.orphans).to_utf8_buffer().size() > 65536 or JSON.stringify(out).to_utf8_buffer().size() > MAX_BYTES: return {"ok": false}
	return {"ok": true, "state": out}

static func _merge_encounters(active: Dictionary, retired: Dictionary) -> Dictionary:
	var out := active
	for pid in retired:
		if not out.has(pid): out[pid] = {}
		for npc in retired[pid]:
			var r: Dictionary = retired[pid][npc]
			var old: Dictionary = out[pid].get(npc, {})
			var ranks := {"space": 0, "listen": 1, "clarify": 2}
			if int(r.day) > int(old.get("day", 0)) or (r.day == old.get("day") and ranks[r.response] > ranks.get(old.get("response"), -1)): out[pid][npc] = r
	return out

static func _decode_players(raw: Variant, day: int) -> Dictionary:
	if not raw is Dictionary or raw.size() > PLAYERS.size():
		return {"ok": false}
	var rows := {}
	for pid in raw:
		if pid not in PLAYERS or not raw[pid] is Dictionary or not _keys(raw[pid], ["npcs"]):
			return {"ok": false}
		var npcs: Variant = raw[pid].get("npcs", {})
		if not npcs is Dictionary or npcs.size() > 256:
			return {"ok": false}
		for npc in npcs:
			if not _id(npc) or not npcs[npc] is Dictionary:
				return {"ok": false}
			var row: Dictionary = npcs[npc]
			if not _keys(row, ["memories", "source_watermarks"]):
				return {"ok": false}
			var stamps: Variant = row.get("source_watermarks", {})
			var details: Variant = row.get("memories", [])
			if not stamps is Dictionary or stamps.size() > 1 or not details is Array or details.size() > 64:
				return {"ok": false}
			var watermark := 0
			for source in stamps:
				if source != SOURCE or npc != NPC or not _whole(stamps[source], 1, MAX_DAY):
					return {"ok": false}
				watermark = int(stamps[source])
			var memories: Array = []
			var seen := {}
			for m in details:
				if not m is Dictionary or not _keys(m, ["event_id", "kind", "day", "source", "subject", "visibility"]) or not _whole(m.get("day"), 1, MAX_DAY):
					return {"ok": false}
				var md := int(m.day)
				if npc != NPC or m.get("source") != SOURCE or m.get("kind") != "helped_smith" or m.get("subject") != NPC or m.get("visibility") != "private" or m.get("event_id") != _event(pid, md) or md > watermark:
					return {"ok": false}
				if seen.has(md) or (day > 0 and (md > day or day - md >= DETAIL_TTL)):
					continue
				seen[md] = true
				memories.append({"event_id": _event(pid, md), "kind": "helped_smith", "day": md, "source": SOURCE, "subject": NPC, "visibility": "private"})
			memories.sort_custom(func(a, b): return int(a.day) < int(b.day))
			while memories.size() > MAX_MEMORIES:
				memories.pop_front()
			if watermark > 0:
				rows[pid] = {"npcs": {NPC: {"memories": memories, "source_watermarks": {SOURCE: watermark}}}}
	return {"ok": true, "rows": rows}

static func _whole(value: Variant, low: int, high: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= low and float(value) <= high

static func _id(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.to_utf8_buffer().size() > 96:
		return false
	for c in value:
		if c not in "abcdefghijklmnopqrstuvwxyz0123456789_":
			return false
	return true

static func _keys(value: Dictionary, allowed: Array) -> bool:
	for key in value:
		if key not in allowed:
			return false
	return true

## Iterative safety walk: depth, work, width and bytes bounded before stringify
## or duplicate. Runtime objects, cyclic graphs and nonfinite floats fail closed.
static func _bounded_json(raw: Variant) -> bool:
	var pending: Array = [[raw, 0]]
	var count := 0
	var bytes := 0
	while not pending.is_empty():
		var entry: Array = pending.pop_back()
		var v: Variant = entry[0]
		var depth: int = entry[1]
		count += 1
		if count > 16384 or depth > 12:
			return false
		match typeof(v):
			TYPE_DICTIONARY:
				if v.size() > 256: return false
				for key in v:
					if not key is String or key.to_utf8_buffer().size() > 96: return false
					bytes += key.to_utf8_buffer().size() + 4
					pending.append([v[key], depth + 1])
			TYPE_ARRAY:
				if v.size() > 64: return false
				for child in v: pending.append([child, depth + 1])
			TYPE_STRING:
				if v.length() > 1024: return false
				bytes += v.to_utf8_buffer().size() + 2
			TYPE_INT, TYPE_BOOL, TYPE_NIL:
				bytes += 24
			TYPE_FLOAT:
				if not is_finite(v): return false
				bytes += 24
			_:
				return false
		if bytes > MAX_BYTES: return false
	return JSON.stringify(raw).to_utf8_buffer().size() <= MAX_BYTES

