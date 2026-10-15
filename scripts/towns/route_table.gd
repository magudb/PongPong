class_name RouteTable
extends RefCounted
## The baked WALKING-DISTANCE TABLE of the towns (data/towns/routes.json, written by tools/towns/bake_routes.gd from the real nav grids) and the planner on top of it.
## Anchors are `area.name` strings: `hyggebyen.torv_fountain_n`, `traetoppen.door_bageriet`, `int_bageriet.counter`, gates `traetoppen.gate_hyggebyen`.
## Per area the table holds the pairwise path length in GROUND px between every anchor; areas are joined by PORTALS (a door and its interior door, a bridge end and the
## far bridge end). path(a, b) = the shortest chain: (a -> portal of its area) + portal links + (portal of the target area -> b). Pure and static: no node, no autoload.

const PORTAL_SECONDS_DEFAULT := 0.5
const SPEED_DEFAULT := 185.0                   # ground px / s of a scheduled leg (towns.npc_speed 0.65 x walk 285)
const GAME_MIN_PER_S_DEFAULT := 2.0            # game.minutes_per_real_second

static var _loaded: bool = false
static var _names: Dictionary = {}             # area -> PackedStringArray
static var _idx: Dictionary = {}               # area -> {name -> index}
static var _d: Dictionary = {}                 # area -> Array[Array[int]] ground px (-1 = unreachable)
static var _links: Dictionary = {}             # portal anchor -> Array[anchor]
static var _portals_of_area: Dictionary = {}   # area -> Array[anchor]
static var _cache: Dictionary = {}             # "a|b" -> Array of legs
static var _cap: Dictionary = {}               # anchor -> capacity (people at once; doors 99)
static var _positions: Dictionary = {}         # anchor -> resolved GROUND px (area local)
static var speed: float = SPEED_DEFAULT
static var portal_seconds: float = PORTAL_SECONDS_DEFAULT
static var game_min_per_s: float = GAME_MIN_PER_S_DEFAULT
static var fallbacks_used: int = 0


static func load_table(path: String = "res://data/towns/routes.json") -> bool:
	speed = maxf(1.0, LuaData.num(Svc.lua_config("towns.npc_speed", 0.65)) * LuaData.num(Svc.lua_config("player.walk_speed", 285.0)))
	portal_seconds = maxf(0.0, LuaData.num(Svc.lua_config("towns.portal_seconds", PORTAL_SECONDS_DEFAULT)))
	game_min_per_s = maxf(0.001, LuaData.num(Svc.lua_config("game.minutes_per_real_second", GAME_MIN_PER_S_DEFAULT)))
	_names.clear()
	_idx.clear()
	_d.clear()
	_links.clear()
	_portals_of_area.clear()
	_cache.clear()
	_cap.clear()
	_positions.clear()
	fallbacks_used = 0
	_loaded = false
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return false
	var areas: Dictionary = (parsed as Dictionary).get("areas", {})
	for aid in areas:
		var a: Dictionary = areas[aid]
		var names: Array = a["names"]
		_names[aid] = PackedStringArray(names)
		var ix: Dictionary = {}
		for i in names.size():
			ix[str(names[i])] = i
		_idx[aid] = ix
		_d[aid] = a["d"]
		var caps: Array = a.get("cap", [])
		var positions: Array = a.get("pos", [])
		for i2 in names.size():
			_cap["%s.%s" % [aid, names[i2]]] = int(caps[i2]) if i2 < caps.size() else 1
			if i2 < positions.size():
				_positions["%s.%s" % [aid, names[i2]]] = Vector2(float(positions[i2][0]), float(positions[i2][1]))
	for pr in (parsed as Dictionary).get("portals", []):
		var p: String = str(pr[0])
		var q: String = str(pr[1])
		for pair in [[p, q], [q, p]]:
			if not _links.has(pair[0]):
				_links[pair[0]] = []
			(_links[pair[0]] as Array).append(pair[1])
	for portal in _links:
		var area: String = str(portal).get_slice(".", 0)
		if not _portals_of_area.has(area):
			_portals_of_area[area] = []
		(_portals_of_area[area] as Array).append(portal)
	_loaded = true
	return true


static func capacity(anchor: String) -> int:
	return int(_cap.get(anchor, 1))


static func position_of(anchor: String) -> Vector2:
	return _positions.get(_canon(anchor), Vector2.INF)


static func is_loaded() -> bool:
	return _loaded


static func has_anchor(anchor: String) -> bool:
	var area: String = anchor.get_slice(".", 0)
	return _idx.has(area) and (_idx[area] as Dictionary).has(_canon(anchor).substr(area.length() + 1))


## A festival satellite (`area.fest_<spot>_gather_3`) is not a row of the table: it is its spot's host plus a short local walk.
static func _canon(anchor: String) -> String:
	var area: String = anchor.get_slice(".", 0)
	var nm: String = anchor.substr(area.length() + 1)
	return "%s.%s" % [area, FestSet.host_of(nm)] if FestSet.is_satellite(nm) else anchor


static func area_of(anchor: String) -> String:
	return anchor.get_slice(".", 0)


static func anchors_of(area: String) -> PackedStringArray:
	return _names.get(area, PackedStringArray())


static func _dist(a: String, b: String) -> float:
	## ground px inside ONE area; -1 when unknown
	var area: String = a.get_slice(".", 0)
	if a == b:
		return 0.0
	if not _idx.has(area):
		return -1.0
	var ia: Variant = (_idx[area] as Dictionary).get(a.substr(area.length() + 1), null)
	var ib: Variant = (_idx[area] as Dictionary).get(b.substr(area.length() + 1), null)
	if ia == null or ib == null:
		return -1.0
	return float(((_d[area] as Array)[ia] as Array)[ib])


## Legs of the shortest chain from anchor a to anchor b: [{kind: "walk"|"portal", area, from, to, seconds}] (empty = no route).
static func path(a: String, b: String) -> Array:
	if a == b:
		return []
	var key: String = a + "|" + b
	if _cache.has(key):
		return _cache[key]
	var ca: String = _canon(a)
	var cb: String = _canon(b)
	var legs: Array = _plan(ca, cb) if ca != cb else []
	if ca != a:
		legs.push_front({"kind": "walk", "area": a.get_slice(".", 0), "from": a, "to": ca, "seconds": FestSet.LOCAL_SECONDS})
	if cb != b:
		legs.append({"kind": "walk", "area": b.get_slice(".", 0), "from": cb, "to": b, "seconds": FestSet.LOCAL_SECONDS})
	_cache[key] = legs
	return legs


static func seconds(a: String, b: String) -> float:
	var t: float = 0.0
	for l in path(a, b):
		t += float(l["seconds"])
	return t


static func game_hours(a: String, b: String) -> float:
	return seconds(a, b) * game_min_per_s / 60.0


static func _plan(a: String, b: String) -> Array:
	var aa: String = a.get_slice(".", 0)
	var ab: String = b.get_slice(".", 0)
	if aa == ab:
		var d: float = _dist(a, b)
		if d < 0.0:
			return _fallback(a, b)
		return [{"kind": "walk", "area": aa, "from": a, "to": b, "seconds": d / speed}]
	# Dijkstra over the portal anchors, with a and b as virtual end nodes
	var dist: Dictionary = {}
	var prev: Dictionary = {}
	var open: Array = []                       # [cost, node] pairs, small: linear scan
	for p in (_portals_of_area.get(aa, []) as Array):
		var d0: float = _dist(a, p)
		if d0 >= 0.0:
			dist[p] = d0 / speed
			prev[p] = a
			open.append([dist[p], p])
	var best_cost: float = INF
	var best_last: String = ""
	var done: Dictionary = {}
	while not open.is_empty():
		var bi: int = 0
		for i in open.size():
			if (open[i][0] as float) < (open[bi][0] as float):
				bi = i
		var cur: Array = open[bi]
		open.remove_at(bi)
		var u: String = cur[1]
		if done.has(u):
			continue
		done[u] = true
		var cu: float = cur[0]
		if cu >= best_cost:
			break
		if u.get_slice(".", 0) == ab:
			var dt: float = _dist(u, b)
			if dt >= 0.0 and cu + dt / speed < best_cost:
				best_cost = cu + dt / speed
				best_last = u
		for q in (_links.get(u, []) as Array):            # through the portal link
			var nc: float = cu + portal_seconds
			if nc < float(dist.get(q, INF)):
				dist[q] = nc
				prev[q] = u
				open.append([nc, q])
		var ua: String = u.get_slice(".", 0)               # walk to the other portals of the same area
		for p2 in (_portals_of_area.get(ua, []) as Array):
			if p2 == u or done.has(p2):
				continue
			var dd: float = _dist(u, p2)
			if dd < 0.0:
				continue
			var nc2: float = cu + dd / speed
			if nc2 < float(dist.get(p2, INF)):
				dist[p2] = nc2
				prev[p2] = u
				open.append([nc2, p2])
	if best_last == "":
		return _fallback(a, b)
	var chain: Array = [b]
	var cur_n: String = best_last
	while cur_n != a:
		chain.push_front(cur_n)
		cur_n = prev[cur_n]
	chain.push_front(a)
	var legs: Array = []
	for i in range(chain.size() - 1):
		var x: String = chain[i]
		var y: String = chain[i + 1]
		if x.get_slice(".", 0) == y.get_slice(".", 0):
			legs.append({"kind": "walk", "area": x.get_slice(".", 0), "from": x, "to": y, "seconds": _dist(x, y) / speed})
		else:
			legs.append({"kind": "portal", "area": "", "from": x, "to": y, "seconds": portal_seconds})
	return legs


## No baked route (a post of an area that is not baked yet, e.g. a map that lands later): straight-line estimate is not possible without positions,
## so the leg takes a fixed 40 s and the validator `routes.complete` reports it. Nothing crashes, nothing teleports silently.
static func _fallback(a: String, b: String) -> Array:
	fallbacks_used += 1
	return [{"kind": "walk", "area": a.get_slice(".", 0), "from": a, "to": b, "seconds": 40.0, "estimated": true}]
