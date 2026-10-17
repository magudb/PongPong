class_name DungeonGen
extends RefCounted
## DESIGNER A (generator track) prototype: the chained-floor Moerkeskoven generator, v1.
## Built on the tech analyst's "clearings and trails" prototype (analysis/proto/dg_gen.gd, snapshot + sha256 in ../base_techanalyst_snapshot/):
## same integer-only discipline (own sfc32 RNG dg_rng.gd, no engine RNG, no float except IEEE sqrt, no Array.sort on ties), same pipeline skeleton
## (sites -> blobs -> MST+loops graph -> winding trails -> ponds -> features -> decor -> validate -> retry), and these additions:
##   * floor spec from lua/config/dungeon.lua (spec_for) instead of a stand-in table; bands with terrain chars
##   * BOSS floors: the last grid column is ONE arena clearing (up to 13 x 23 cells), Hulen sealed on the far side, boss + sealed chest
##   * secret NOOKS: 1-wide spur + 5x5 diamond pocket cut into the forest wall; they host unique spots, quest anchors and hidden chests
##   * ambush spots (bush eyes) next to the trail, a tutorial ambush 6-11 cells from the spawn on floors 1-2
##   * lake chest on the shore of the biggest pond (key chest), up-warp (arrival cave), spawn `from_down`, runestone in the arrival clearing
##   * free-standing INNER CROWNS (solid canopy balls, the "bubbles as obstacles" of the v2 sketch)
##   * a deterministic mirror (flip x / flip y) of the finished floor, so the route is not always west to east
## Coordinates here are the PLAY area (w x h). dg2_export.gd pads it with void, adds the rim crowns and writes the AreaMap text.

const Rng := preload("res://scripts/dungeon/gen/dungeon_rng.gd")

const G_WALL: int = 87     # 'W'
const G_POND: int = 126    # '~'
const BORDER: int = 3

const D_ROCK: int = 2
const D_BUSH: int = 3
const D_LILY: int = 4
const D_SHROOM: int = 5
const D_ICROWN_S: int = 6
const D_ICROWN_M: int = 7

## Canopy "sphere" geometry in SCREEN px (ortho cell 96 x 56). Class 0/1/2 = S/M/L, radius of the crown disc; the sphere centre sits 0.81 R above the
## ground contact point (a sphere resting on the ground seen from 36 degrees). Source of the sizes: analysis/v2_environment.md 4.2 (crown classes).
const CELL_W: int = 96
const CELL_H: int = 56
const CROWN_R: Array[int] = [170, 230, 300]
static var _crown_rows: Array = []
static var _crown_lock := Mutex.new()


## Rows of the disc of class `cls` in CELL offsets from the anchor cell: Vector3i(dj, di_lo, di_hi) (cell centres inside the disc).
@warning_ignore("integer_division")
static func crown_rows(cls: int) -> Array:
	_crown_lock.lock()
	if _crown_rows.is_empty():
		for k in 3:
			var r: int = CROWN_R[k]
			var up: int = r * 81 / 100
			var rows: Array = []
			for dj in range(-((r + up) / CELL_H) - 2, (r - up) / CELL_H + 3):
				var lo: int = 99
				var hi: int = -99
				for di in range(-6, 7):
					var vx: int = di * CELL_W
					var vy: int = dj * CELL_H + up
					if vx * vx + vy * vy <= r * r:
						lo = mini(lo, di)
						hi = maxi(hi, di)
				if hi >= lo:
					rows.append(Vector3i(dj, lo, hi))
			_crown_rows.append(rows)
	var result: Array = _crown_rows[cls]
	_crown_lock.unlock()
	return result


## Does the disc of class `cls` anchored at cell (x, y) contain the CENTRE of cell (fx, fy)?  (a half cell of margin is added: a feature that is half under the leaves counts)
@warning_ignore("integer_division")
static func crown_covers(cls: int, x: int, y: int, fx: int, fy: int) -> bool:
	var r: int = CROWN_R[cls] + 48
	var up: int = CROWN_R[cls] * 81 / 100
	var vx: int = (fx - x) * CELL_W
	var vy: int = (fy - y) * CELL_H + up
	return vx * vx + vy * vy <= r * r

class Fl extends RefCounted:
	var w: int = 0
	var h: int = 0
	var seed_value: int = 0
	var attempt_seed: int = 0
	var attempts: int = 0
	var ground: PackedByteArray = PackedByteArray()
	var trail: PackedByteArray = PackedByteArray()      # 1 = trail / nook cell (protected from ponds and decor)
	var blocked: PackedByteArray = PackedByteArray()    # 1 = a solid prop or solid feature
	var occupied: PackedByteArray = PackedByteArray()   # 1 = a feature stands here
	var decor: PackedByteArray = PackedByteArray()
	var near_feat: PackedByteArray = PackedByteArray()
	var nookmask: PackedByteArray = PackedByteArray()   # 1 = nook spur / pocket cell
	var feats: Array = []
	var clearings: Array = []
	var edges: Array = []
	var nooks: Array = []
	var entry: Vector2i = Vector2i.ZERO
	var exit_cell: Vector2i = Vector2i.ZERO
	var flip_x: bool = false
	var flip_y: bool = false
	var stats: Dictionary = {}
	var spec: Dictionary = {}
	var phase_us: Array = []
	var first_fail: String = ""
	var t_floor: int = 109
	var t_patch: int = 103
	var t_path: int = 112

	func idx(x: int, y: int) -> int:
		return y * w + x


# ------------------------------------------------------------------------------------------------ spec

static func spec_for(cfg: Dictionary, floor_number: int) -> Dictionary:
	return DungeonSpec.spec_for(cfg,floor_number)

# ------------------------------------------------------------------------------------------------ public API

## EDITOR'S FINAL PASS (defect "the safety net is not prototyped"): `generate` = up to `max_attempts` ordinary attempts, and when ALL of them fail (or max_attempts == 0, the test switch)
## the PINNED FALLBACK of the table: the ordinary generator run ONCE on the seed `fallback_seed` that tools/dungeon/find_fallback_seeds picked for this floor (the first seed of a
## fixed sequence that passes the verifier at its first attempt).  It is a normal floor (nooks, spots, anchors, boss arena ...), so every invariant of the verifier holds
## by MEASUREMENT (fallback_check.gd: 12 specs x verifier), not by construction.  Same table => same floor every time it happens (about 1 floor in 10 000).
func generate(seed_value: int, spec: Dictionary, max_attempts: int = 8) -> Fl:
	var fl: Fl = _run(seed_value, spec, max_attempts)
	if bool(fl.stats.get("ok", false)):
		return fl
	var fb_seed: int = int(spec.get("fallback_seed", 0))
	if fb_seed == 0:
		return fl
	var fb: Fl = _run(fb_seed, spec, 1)
	fb.stats["fallback"] = true
	fb.first_fail = fl.first_fail
	fb.attempts = fl.attempts + 1
	return fb


func _run(seed_value: int, spec: Dictionary, max_attempts: int) -> Fl:
	var fl := Fl.new()
	fl.w = int(spec["w"])
	fl.h = int(spec["h"])
	fl.spec = spec
	fl.seed_value = seed_value
	var tr: Dictionary = spec["terrain"] as Dictionary
	fl.t_floor = str(tr["floor"]).unicode_at(0)
	fl.t_patch = str(tr["patch"]).unicode_at(0)
	fl.t_path = str(tr["path"]).unicode_at(0)
	for attempt in max_attempts:
		fl.attempts = attempt + 1
		var s: int = seed_value if attempt == 0 else Rng.hash_key("retry", seed_value & 0xFFFFFFFF, attempt)
		fl.attempt_seed = s
		var rng = Rng.new(s)
		if _attempt(fl, rng):
			fl.stats["ok"] = true
			return fl
		if fl.first_fail == "":
			fl.first_fail = str(fl.stats.get("fail", "?"))
	fl.stats["ok"] = false
	return fl


func _attempt(fl: Fl, rng) -> bool:
	var w: int = fl.w
	var h: int = fl.h
	fl.ground = PackedByteArray()
	fl.ground.resize(w * h)
	fl.ground.fill(G_WALL)
	for nm in ["trail", "blocked", "occupied", "decor", "nookmask", "near_feat"]:
		var pa := PackedByteArray()
		pa.resize(w * h)
		fl.set(nm, pa)
	fl.feats = []
	fl.clearings = []
	fl.edges = []
	fl.nooks = []
	fl.stats = {"ok": false}
	var t0: int = Time.get_ticks_usec()
	_make_sites(fl, rng)
	_carve_clearings(fl, rng)
	var t1: int = Time.get_ticks_usec()
	_connect(fl, rng)
	var t2: int = Time.get_ticks_usec()
	_carve_trails(fl, rng)
	_ponds(fl, rng)
	var t3: int = Time.get_ticks_usec()
	fl.stats["repaired_a"] = _repair_islands(fl)
	var t3b: int = Time.get_ticks_usec()
	if not _carve_nooks(fl, rng):
		fl.stats["fail"] = "nooks"
		return false
	var t4: int = Time.get_ticks_usec()
	_place_features(fl, rng)
	_mirror(fl, rng)           # before the canopy: a crown disc is not mirror-symmetric (it rises above its anchor)
	var t5: int = Time.get_ticks_usec()
	_place_inner_crowns(fl, rng)
	_place_decor(fl, rng)
	fl.stats["repaired_b"] = _repair_islands(fl)
	var t6: int = Time.get_ticks_usec()
	var ok: bool = _validate(fl)
	var t7: int = Time.get_ticks_usec()
	fl.phase_us = [t1 - t0, t2 - t1, t3 - t2, t3b - t3, t4 - t3b, t5 - t4, t6 - t5, t7 - t6]
	return ok


# ------------------------------------------------------------------------------------------------ 1 sites

@warning_ignore("integer_division")
func _make_sites(fl: Fl, rng) -> void:
	var inner_w: int = fl.w - 2 * (BORDER + 3)
	var inner_h: int = fl.h - 2 * (BORDER + 3)
	var cols: int = maxi(3, (inner_w + 5) / 14)
	var rows: int = maxi(2, (inner_h + 5) / 17)
	var bw: int = inner_w / cols
	var bh: int = inner_h / rows
	var ox: int = BORDER + 3
	var oy: int = BORDER + 3
	var entry_row: int = rng.below(rows)
	var exit_row: int = rng.below(rows)
	var id: int = 0
	var skip_pct: int = int(fl.spec.get("skip_pct", 15))
	var boss: bool = bool(fl.spec.get("boss", false))
	for c in cols:
		if boss and c == cols - 1:
			var rv: int = mini(11, inner_h / 2 - 1)
			var rx: int = (rv * 4 + 3) / 7
			var cx: int = clampi(ox + c * bw + bw / 2, BORDER + rx + 2, fl.w - BORDER - rx - 4)
			var cy: int = oy + inner_h / 2
			fl.exit_cell = Vector2i(cx, cy)
			fl.clearings.append({"cx": cx, "cy": cy, "rx": rx, "ry": rv, "kind": "exit", "id": id, "col": c, "row": 0, "big": true})
			id += 1
			continue
		for r in rows:
			var is_entry: bool = c == 0 and r == entry_row
			var is_exit: bool = c == cols - 1 and r == exit_row
			if not is_entry and not is_exit and rng.below(100) < skip_pct:
				continue
			var big: bool = rng.below(100) < 40 or is_entry
			var rv2: int = rng.range_i(6, 8) if big else rng.range_i(4, 6)
			rv2 = mini(rv2, bh / 2 - 1)
			var rx2: int = (rv2 * 4 + 3) / 7
			var jx: int = bw / 2 - rx2 - 1
			var jy: int = bh / 2 - rv2 + 1
			var cx2: int = ox + c * bw + bw / 2 + (rng.range_i(-jx, jx) if jx > 0 else 0)
			var cy2: int = oy + r * bh + bh / 2 + (rng.range_i(-jy, jy) if jy > 0 else 0)
			cx2 = clampi(cx2, BORDER + rx2 + 2, fl.w - BORDER - rx2 - 3)
			cy2 = clampi(cy2, BORDER + rv2 + 2, fl.h - BORDER - rv2 - 3)
			var kind: String = "clearing"
			if is_entry:
				kind = "entry"
				fl.entry = Vector2i(cx2, cy2)
			elif is_exit:
				kind = "exit"
				fl.exit_cell = Vector2i(cx2, cy2)
			fl.clearings.append({"cx": cx2, "cy": cy2, "rx": rx2, "ry": rv2, "kind": kind, "id": id, "col": c, "row": r, "big": big})
			id += 1
	fl.stats["sites"] = fl.clearings.size()


func _ellipse(fl: Fl, cx: int, cy: int, rx: int, ry: int, code: int, only_wall: bool) -> void:
	var rx2: int = rx * rx
	var ry2: int = ry * ry
	var lim: int = rx2 * ry2
	for y in range(maxi(cy - ry, 1), mini(cy + ry, fl.h - 2) + 1):
		var dy: int = y - cy
		for x in range(maxi(cx - rx, 1), mini(cx + rx, fl.w - 2) + 1):
			var dx: int = x - cx
			if dx * dx * ry2 + dy * dy * rx2 <= lim:
				var i: int = y * fl.w + x
				if not only_wall or fl.ground[i] == G_WALL:
					fl.ground[i] = code


@warning_ignore("integer_division")
func _carve_clearings(fl: Fl, rng) -> void:
	for cl in fl.clearings:
		var cx: int = cl["cx"]
		var cy: int = cl["cy"]
		var rx: int = cl["rx"]
		var ry: int = cl["ry"]
		_ellipse(fl, cx, cy, rx, ry, fl.t_floor, false)
		for k in 2:
			var sx: int = cx + (rx * 6 / 10) * (1 if rng.below(2) == 0 else -1)
			var sy: int = cy + rng.range_i(-ry / 3, ry / 3)
			_ellipse(fl, sx, sy, maxi(2, rx * 7 / 10), maxi(2, ry * 7 / 10), fl.t_floor, false)


# ------------------------------------------------------------------------------------------------ 3 graph

func _d2(ax: int, ay: int, bx: int, by: int) -> int:
	var dx: int = ax - bx
	var dy: int = ay - by
	return 3 * dx * dx + dy * dy


@warning_ignore("integer_division")
func _connect(fl: Fl, rng) -> void:
	var n: int = fl.clearings.size()
	if n < 2:
		return
	var in_tree := PackedByteArray()
	in_tree.resize(n)
	in_tree[0] = 1
	var tree_edges: Array = []
	for step in n - 1:
		var best: int = 1 << 60
		var ba: int = -1
		var bb: int = -1
		for a in n:
			if in_tree[a] == 0:
				continue
			for b in n:
				if in_tree[b] == 1:
					continue
				var d: int = _d2(fl.clearings[a]["cx"], fl.clearings[a]["cy"], fl.clearings[b]["cx"], fl.clearings[b]["cy"])
				if d < best:
					best = d
					ba = a
					bb = b
		in_tree[bb] = 1
		tree_edges.append(Vector3i(ba, bb, 0))
	var have: Dictionary = {}
	for e in tree_edges:
		have[mini(e.x, e.y) * 1000 + maxi(e.x, e.y)] = true
	var cand: Array = []
	for a in n:
		for b in range(a + 1, n):
			if have.has(a * 1000 + b):
				continue
			cand.append(Vector3i(_d2(fl.clearings[a]["cx"], fl.clearings[a]["cy"], fl.clearings[b]["cx"], fl.clearings[b]["cy"]), a, b))
	cand.sort_custom(func(p: Vector3i, q: Vector3i) -> bool:
		if p.x != q.x:
			return p.x < q.x
		if p.y != q.y:
			return p.y < q.y
		return p.z < q.z)
	var extra: int = mini(cand.size(), n / 3)
	var added: int = 0
	for c in cand:
		if added >= extra:
			break
		if rng.below(100) < 70:
			tree_edges.append(Vector3i(c.y, c.z, 0))
			added += 1
	fl.edges = tree_edges
	var ei: int = _clearing_of_kind(fl, "entry")
	var xi: int = _clearing_of_kind(fl, "exit")
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-2)
	prev[ei] = -1
	var q: Array = [ei]
	var head: int = 0
	while head < q.size():
		var a2: int = q[head]
		head += 1
		for e in fl.edges:
			var o: int = -1
			if e.x == a2:
				o = e.y
			elif e.y == a2:
				o = e.x
			if o >= 0 and prev[o] == -2:
				prev[o] = a2
				q.append(o)
	var cur: int = xi
	var main_pairs: Dictionary = {}
	while cur >= 0 and prev[cur] >= 0:
		main_pairs[mini(cur, prev[cur]) * 1000 + maxi(cur, prev[cur])] = true
		cur = prev[cur]
	for i in fl.edges.size():
		var e2: Vector3i = fl.edges[i]
		if main_pairs.has(mini(e2.x, e2.y) * 1000 + maxi(e2.x, e2.y)):
			fl.edges[i] = Vector3i(e2.x, e2.y, 1)
	fl.stats["edges"] = fl.edges.size()


func _clearing_of_kind(fl: Fl, kind: String) -> int:
	for i in fl.clearings.size():
		if fl.clearings[i]["kind"] == kind:
			return i
	return 0


# ------------------------------------------------------------------------------------------------ 4 trails

@warning_ignore("integer_division")
func _carve_trails(fl: Fl, rng) -> void:
	for pass_main in 2:
		for e in fl.edges:
			if int(e.z) != pass_main:
				continue
			var a: Dictionary = fl.clearings[e.x]
			var b: Dictionary = fl.clearings[e.y]
			var stream: int = rng.next_u32()
			var width: int = 3 if pass_main == 1 else (2 if rng.below(4) == 0 else 1)
			_carve_trail(fl, a["cx"], a["cy"], b["cx"], b["cy"], stream, width, fl.t_path if pass_main == 1 else fl.t_floor)


@warning_ignore("integer_division")
func _carve_trail(fl: Fl, ax: int, ay: int, bx: int, by: int, stream: int, width: int, code: int) -> void:
	var dx: int = bx - ax
	var dy: int = by - ay
	var len2: int = dx * dx + dy * dy
	var length: int = maxi(1, int(sqrt(float(len2))))
	var steps: int = maxi(absi(dx), absi(dy)) * 2 + 2
	var lobes: int = maxi(2, length / 9)
	var amp: int = clampi(length / 3, 3, 9)
	for i in steps + 1:
		var t: int = i * 1000 / steps
		var env: int = 4 * t * (1000 - t) / 1000
		var nz: int = Rng.noise1(stream, t * lobes) * 3 / 4 + Rng.noise1(stream ^ 0x5bd1e995, t * lobes * 2) / 4
		var off: int = nz * amp * env / 1000000
		var px: int = ax + dx * i / steps + (-dy * off) / length
		var py: int = ay + dy * i / steps + (dx * off) / length
		_stamp(fl, px, py, width, code)


func _stamp(fl: Fl, px: int, py: int, width: int, code: int) -> void:
	var rx: int = 0
	var ry: int = 0
	match width:
		1:
			rx = 0
			ry = 1
		2:
			rx = 1
			ry = 1
		_:
			rx = 1
			ry = 2
	for y in range(py - ry, py + ry + 1):
		if y < BORDER or y >= fl.h - BORDER:
			continue
		for x in range(px - rx, px + rx + 1):
			if x < BORDER or x >= fl.w - BORDER:
				continue
			if width == 2 and absi(x - px) + absi(y - py) > 1:
				continue
			var i: int = y * fl.w + x
			fl.trail[i] = 1
			if code == fl.t_path or fl.ground[i] == G_WALL:
				fl.ground[i] = code


# ------------------------------------------------------------------------------------------------ 5 ponds

@warning_ignore("integer_division")
func _ponds(fl: Fl, rng) -> void:
	var want: int = int(fl.spec.get("ponds", 0))
	fl.stats["ponds"] = 0
	if want <= 0:
		return
	var order: Array = []
	for cl in fl.clearings:
		if cl["kind"] == "clearing" and int(cl["ry"]) >= 6:
			order.append(cl)
	rng.shuffle(order)
	var order2: Array = []
	for cl in fl.clearings:
		if cl["kind"] == "clearing" and int(cl["ry"]) < 6 and int(cl["ry"]) >= 4:
			order2.append(cl)
	rng.shuffle(order2)
	order.append_array(order2)
	var made: int = 0
	for cl in order:
		if made >= want:
			break
		var rx: int = maxi(2, int(cl["rx"]) * 6 / 10)
		var ry: int = maxi(2, int(cl["ry"]) * 5 / 10)
		var sx: int = int(cl["cx"]) + (int(cl["rx"]) / 3) * (1 if rng.below(2) == 0 else -1)
		var sy: int = int(cl["cy"]) + (int(cl["ry"]) / 3) * (1 if rng.below(2) == 0 else -1)
		var rx2: int = rx * rx
		var ry2: int = ry * ry
		var lim: int = rx2 * ry2
		var cells: int = 0
		for y in range(sy - ry, sy + ry + 1):
			for x in range(sx - rx, sx + rx + 1):
				if x < BORDER + 1 or y < BORDER + 1 or x >= fl.w - BORDER - 1 or y >= fl.h - BORDER - 1:
					continue
				var dx: int = x - sx
				var dy: int = y - sy
				if dx * dx * ry2 + dy * dy * rx2 > lim:
					continue
				var i: int = y * fl.w + x
				if fl.trail[i] == 1 or fl.ground[i] == G_WALL:
					continue
				fl.ground[i] = G_POND
				cells += 1
		if cells > 0:
			made += 1
			cl["pond"] = Vector3i(sx, sy, cells)
	fl.stats["ponds"] = made


# ------------------------------------------------------------------------------------------------ helpers

func _walkable(fl: Fl, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= fl.w or y >= fl.h:
		return false
	var g: int = fl.ground[y * fl.w + x]
	return g != G_WALL and g != G_POND


func _free(fl: Fl, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= fl.w or y >= fl.h:
		return false
	var i: int = y * fl.w + x
	var g: int = fl.ground[i]
	return g != G_WALL and g != G_POND and fl.blocked[i] == 0


## "simple point" test: would a solid object at (x, y) keep the walkable cells around it locally connected?
func can_block(fl: Fl, x: int, y: int) -> bool:
	var n: int = 1 if _free(fl, x, y - 1) else 0
	var e: int = 1 if _free(fl, x + 1, y) else 0
	var s: int = 1 if _free(fl, x, y + 1) else 0
	var wv: int = 1 if _free(fl, x - 1, y) else 0
	var ne: int = 1 if _free(fl, x + 1, y - 1) else 0
	var se: int = 1 if _free(fl, x + 1, y + 1) else 0
	var sw: int = 1 if _free(fl, x - 1, y + 1) else 0
	var nw: int = 1 if _free(fl, x - 1, y - 1) else 0
	var k: int = n + e + s + wv
	if k == 0:
		return true
	var groups: int = k - (n & e & ne) - (e & s & se) - (s & wv & sw) - (wv & n & nw)
	return groups <= 1


func _put(fl: Fl, t: String, c: Vector2i, extra: Dictionary = {}, solid: bool = false) -> Dictionary:
	var f: Dictionary = {"t": t, "x": c.x, "y": c.y, "id": fl.feats.size()}
	for k in extra:
		f[k] = extra[k]
	fl.feats.append(f)
	var i: int = c.y * fl.w + c.x
	fl.occupied[i] = 1
	if solid:
		fl.blocked[i] = 1
	return f


func _bfs(fl: Fl, start: Vector2i) -> PackedInt32Array:
	var w: int = fl.w
	var h: int = fl.h
	var dist := PackedInt32Array()
	dist.resize(w * h)
	dist.fill(-1)
	var q := PackedInt32Array()
	q.resize(w * h)
	var head: int = 0
	var tail: int = 0
	var s: int = start.y * w + start.x
	dist[s] = 0
	q[tail] = s
	tail += 1
	while head < tail:
		var cur: int = q[head]
		head += 1
		var d: int = dist[cur] + 1
		var cx: int = cur % w
		var cy: int = cur / w
		if cx > 0:
			var n: int = cur - 1
			if dist[n] < 0 and fl.ground[n] != G_WALL and fl.ground[n] != G_POND and fl.blocked[n] == 0:
				dist[n] = d
				q[tail] = n
				tail += 1
		if cx < w - 1:
			var n2: int = cur + 1
			if dist[n2] < 0 and fl.ground[n2] != G_WALL and fl.ground[n2] != G_POND and fl.blocked[n2] == 0:
				dist[n2] = d
				q[tail] = n2
				tail += 1
		if cy > 0:
			var n3: int = cur - w
			if dist[n3] < 0 and fl.ground[n3] != G_WALL and fl.ground[n3] != G_POND and fl.blocked[n3] == 0:
				dist[n3] = d
				q[tail] = n3
				tail += 1
		if cy < h - 1:
			var n4: int = cur + w
			if dist[n4] < 0 and fl.ground[n4] != G_WALL and fl.ground[n4] != G_POND and fl.blocked[n4] == 0:
				dist[n4] = d
				q[tail] = n4
				tail += 1
	return dist


func _repair_islands(fl: Fl) -> int:
	var dist: PackedInt32Array = _bfs(fl, fl.entry)
	var filled: int = 0
	for i in fl.w * fl.h:
		var g: int = fl.ground[i]
		if g != G_WALL and g != G_POND and dist[i] < 0 and fl.blocked[i] == 0:
			fl.ground[i] = G_WALL
			fl.trail[i] = 0
			fl.decor[i] = 0
			filled += 1
	return filled


# ------------------------------------------------------------------------------------------------ 5b nooks

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Marker types whose node is a solid body for the player (mask 197 = world + npc + resource_node + ground_block): they block their cell.
const SOLID_MARKERS: Array[String] = ["node", "chest", "runestone", "unique_spot", "npc", "quest_spot", "hulen_keeper"]


## A solid object at (x, y) must leave itself an entrance (a free 4-neighbour) and must not take the last entrance of a solid neighbour.
func _solid_ok(fl: Fl, x: int, y: int) -> bool:
	var free_n: int = 0
	for o in DIRS:
		if _free(fl, x + o.x, y + o.y):
			free_n += 1
	if free_n == 0:
		return false
	for o in DIRS:
		var nx: int = x + o.x
		var ny: int = y + o.y
		if nx < 0 or ny < 0 or nx >= fl.w or ny >= fl.h:
			continue
		if fl.blocked[ny * fl.w + nx] == 1 and _walkable(fl, nx, ny):
			var keep: bool = false
			for o2 in DIRS:
				var mx: int = nx + o2.x
				var my: int = ny + o2.y
				if mx == x and my == y:
					continue
				if _free(fl, mx, my):
					keep = true
			if not keep:
				return false
	return true

## Pocket shape: diamond of radius 2 (13 cells) around the pocket centre.
func _pocket_cells(p: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if absi(dx) + absi(dy) <= 2:
				out.append(Vector2i(p.x + dx, p.y + dy))
	return out


@warning_ignore("integer_division")
func _carve_nooks(fl: Fl, rng) -> bool:
	var want: int = int(fl.spec.get("nooks", 0))
	if want <= 0:
		return true
	var pool: Array = []
	for cl in fl.clearings:
		if cl["kind"] == "clearing":
			pool.append(cl)
	if pool.is_empty():
		return false
	var made: int = 0
	var tries: int = 0
	while made < want and tries < 160 * want:
		tries += 1
		var cl: Dictionary = pool[rng.below(pool.size())]
		var dir: Vector2i = DIRS[rng.below(4)]
		# walk from the clearing centre in `dir` until the next cell is wall: that floor cell is the mouth
		var x: int = int(cl["cx"])
		var y: int = int(cl["cy"])
		var guard: int = 0
		while _walkable(fl, x + dir.x, y + dir.y) and guard < 40:
			x += dir.x
			y += dir.y
			guard += 1
		var mouth := Vector2i(x, y)
		if fl.ground[mouth.y * fl.w + mouth.x] == G_POND or fl.occupied[mouth.y * fl.w + mouth.x] == 1:
			continue
		var length: int = rng.range_i(4, 8)
		var p := Vector2i(mouth.x + dir.x * (length + 2), mouth.y + dir.y * (length + 2))
		if _d2(p.x, p.y, fl.entry.x, fl.entry.y) < 200:
			continue
		var cells: Array[Vector2i] = []
		for i in range(1, length + 1):
			cells.append(Vector2i(mouth.x + dir.x * i, mouth.y + dir.y * i))
		var pocket: Array[Vector2i] = _pocket_cells(p)
		# everything must lie inside the play area with the forest border kept
		var ok: bool = true
		for c in cells + pocket:
			if c.x < BORDER + 1 or c.y < BORDER + 1 or c.x >= fl.w - BORDER - 1 or c.y >= fl.h - BORDER - 1:
				ok = false
				break
		if not ok:
			continue
		var region: Dictionary = {}
		for c in cells + pocket:
			region[c.y * fl.w + c.x] = true
		var s1: int = cells[0].y * fl.w + cells[0].x
		# every cell touching the region (8-neighbourhood) must be wall, except the mouth and the cells touching the first spur cell
		for c in cells + pocket:
			if fl.ground[c.y * fl.w + c.x] != G_WALL:
				ok = false
				break
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx: int = c.x + dx
					var ny: int = c.y + dy
					var ni: int = ny * fl.w + nx
					if region.has(ni):
						continue
					if nx == mouth.x and ny == mouth.y:
						continue
					if c == cells[0] and absi(nx - mouth.x) <= 1 and absi(ny - mouth.y) <= 1:
						continue
					if fl.ground[ni] != G_WALL:
						ok = false
			if not ok:
				break
		if not ok:
			continue
		fl.trail[mouth.y * fl.w + mouth.x] = 1
		for c in cells + pocket:
			var ci: int = c.y * fl.w + c.x
			fl.ground[ci] = fl.t_floor
			fl.trail[ci] = 1
			fl.nookmask[ci] = 1
		fl.nooks.append({"mouth": mouth, "dir": dir, "pocket": p, "len": length, "clearing": int(cl["id"]), "used": false})
		made += 1
	fl.stats["nooks"] = made
	return made == want


# ------------------------------------------------------------------------------------------------ 6 features

## Free floor cells of a clearing (not trail, not occupied, not nook), optionally edge cells only / at least `min_d2` away from a point.
@warning_ignore("integer_division")
func _cells_of(fl: Fl, cl: Dictionary, edge_only: bool, away_x: int, away_y: int, min_d2: int, solid: bool = false, max_d2: int = 0) -> Array:
	var out: Array = []
	var cx: int = cl["cx"]
	var cy: int = cl["cy"]
	var rx: int = int(cl["rx"]) * 14 / 10 + 1
	var ry: int = int(cl["ry"]) * 14 / 10 + 1
	var lim: int = _d2(cx + int(cl["rx"]) * 14 / 10, cy, cx, cy) + 4
	for y in range(maxi(cy - ry, BORDER), mini(cy + ry, fl.h - BORDER - 1) + 1):
		for x in range(maxi(cx - rx, BORDER), mini(cx + rx, fl.w - BORDER - 1) + 1):
			var i: int = y * fl.w + x
			var g: int = fl.ground[i]
			if g == G_WALL or g == G_POND or fl.trail[i] == 1 or fl.occupied[i] == 1 or fl.blocked[i] == 1:
				continue
			if _d2(x, y, cx, cy) > lim:
				continue
			if edge_only:
				var edge: bool = not _walkable(fl, x - 1, y) or not _walkable(fl, x + 1, y) or not _walkable(fl, x, y - 1) or not _walkable(fl, x, y + 1)
				if not edge:
					continue
			var da: int = _d2(x, y, away_x, away_y)
			if min_d2 > 0 and da < min_d2:
				continue
			if max_d2 > 0 and da > max_d2:
				continue
			if solid and (not can_block(fl, x, y) or not _solid_ok(fl, x, y)):
				continue
			out.append(Vector2i(x, y))
	return out


func _line_d2(px: int, py: int, ex: int, ey: int, fx: int, fy: int) -> int:
	var dx: int = fx - ex
	var dy: int = fy - ey
	var cross: int = dx * (py - ey) - dy * (px - ex)
	var l2: int = maxi(1, dx * dx + dy * dy)
	return (cross * cross * 1000) / l2


func _near_trail(fl: Fl, x: int, y: int, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var nx: int = x + dx
			var ny: int = y + dy
			if nx >= 0 and ny >= 0 and nx < fl.w and ny < fl.h:
				var i: int = ny * fl.w + nx
				if fl.trail[i] == 1 and fl.nookmask[i] == 0 and fl.ground[i] != G_WALL:
					return true
	return false


func _kind_of_mix(mix: Dictionary, rng, allow_stationary: bool = true) -> String:
	var keys: Array = mix.keys()
	keys.sort()
	var weights: Array = []
	for k in keys:
		weights.append(int(mix[k]) if (allow_stationary or str(k) != "tornebusk") else 0)
	return str(keys[rng.weighted(weights)])


@warning_ignore("integer_division")
func _place_features(fl: Fl, rng) -> void:
	var spec: Dictionary = fl.spec
	var floor_no: int = int(spec["floor"])
	var boss: bool = bool(spec["boss"])
	var by_id: Dictionary = {}
	var side: Array = []
	for cl in fl.clearings:
		by_id[cl["id"]] = cl
		if cl["kind"] == "clearing":
			side.append(cl)
	var ec: Dictionary = fl.clearings[_clearing_of_kind(fl, "entry")]
	var xc: Dictionary = fl.clearings[_clearing_of_kind(fl, "exit")]
	# --- spawn and the up-warp (arrival cave) in the entry clearing
	_put(fl, "spawn", fl.entry)
	var up_cells: Array = _cells_of(fl, ec, true, fl.entry.x, fl.entry.y, 36, false, 300)
	if up_cells.is_empty():
		up_cells = _cells_of(fl, ec, false, fl.entry.x, fl.entry.y, 27, false, 400)
	if not up_cells.is_empty():
		_put(fl, "up", up_cells[rng.below(up_cells.size())], {}, false)
	if bool(spec["stone"]):
		var cells: Array = _cells_of(fl, ec, false, fl.entry.x, fl.entry.y, 20, true, 200)
		var far_from_up: Array = []
		for c in cells:
			var upf: Dictionary = {}
			for f0 in fl.feats:
				if str(f0["t"]) == "up":
					upf = f0
			if upf.is_empty() or _d2(c.x, c.y, int(upf["x"]), int(upf["y"])) >= 12:
				far_from_up.append(c)
		if not far_from_up.is_empty():
			var rc: Vector2i = far_from_up[rng.below(far_from_up.size())]
			_put(fl, "runestone", rc, {}, true)
			# the spawn "rune" beside the stone: where "continue from the stone" arrives (compat with the experience track, R-G2)
			var rs: Array = []
			for o in DIRS:
				var nx: int = rc.x + o.x
				var ny: int = rc.y + o.y
				if _walkable(fl, nx, ny) and fl.occupied[ny * fl.w + nx] == 0 and fl.blocked[ny * fl.w + nx] == 0:
					rs.append(Vector2i(nx, ny))
			if not rs.is_empty():
				_put(fl, "spawn_rune", rs[rng.below(rs.size())], {}, false)
	# --- Hulen (+ the `from_down` spawn two cells before it) and the boss arena
	var hx: int = fl.exit_cell.x
	var hy: int = fl.exit_cell.y
	if boss:
		hx = int(xc["cx"]) + int(xc["rx"]) - 2
		hy = int(xc["cy"])
		while not _walkable(fl, hx, hy) and hx > int(xc["cx"]):
			hx -= 1
	if bool(spec["hulen"]):
		_put(fl, "hulen", Vector2i(hx, hy), {"to": floor_no + 1, "sealed": boss}, false)
		fl.ground[hy * fl.w + hx] = fl.t_floor
		var fd: Vector2i = Vector2i(hx - 3, hy) if _walkable(fl, hx - 3, hy) else Vector2i(hx - 2, hy)
		if boss:
			fd = Vector2i(hx - 3, hy + 2) if _walkable(fl, hx - 3, hy + 2) else Vector2i(hx - 3, hy)
		_put(fl, "spawn_down", fd, {}, false)
	else:
		# last floor: no way down; a rope up ("home rope") stands where the Hulen would be, sealed by the boss on a boss floor
		_put(fl, "home", Vector2i(hx, hy), {"sealed": boss}, false)
		fl.ground[hy * fl.w + hx] = fl.t_floor
	if boss:
		var bx: int = int(xc["cx"]) - 2
		var by: int = int(xc["cy"])
		_put(fl, "boss", Vector2i(bx, by), {"kind": str(spec["boss_kind"]), "adds": int(spec["boss_adds"])})
		var chest_cells: Array = _cells_of(fl, xc, true, hx, hy, 0, true, 90)
		if chest_cells.is_empty():
			chest_cells = _cells_of(fl, xc, false, hx, hy, 0, true, 160)
		if not chest_cells.is_empty():
			_put(fl, "chest", chest_cells[rng.below(chest_cells.size())], {"tier": "konge", "role": "boss", "sealed": true, "boss": str(spec["boss_kind"])}, true)
	# --- nooks: unique spots, quest anchors, hidden main chest (in this order)
	var nook_i: int = 0
	for sp in (spec["spots"] as Array):
		if nook_i < fl.nooks.size():
			_put(fl, "spot", fl.nooks[nook_i]["pocket"], {"spot": str(sp)}, true)
			fl.nooks[nook_i]["used"] = true
			nook_i += 1
	for an in (spec["anchors"] as Array):
		if str((an as Dictionary).get("place", "")) == "nook":
			for k in int((an as Dictionary).get("count", 1)):
				if nook_i < fl.nooks.size():
					_put(fl, "anchor", fl.nooks[nook_i]["pocket"], {"marker": str(an["marker"]), "params": str(an["params"])}, str(an["marker"]) in SOLID_MARKERS)
					fl.nooks[nook_i]["used"] = true
					nook_i += 1
	if bool(spec["nook_main"]) and nook_i < fl.nooks.size():
		_put(fl, "chest", fl.nooks[nook_i]["pocket"], {"tier": str(spec["chest_tier"]), "role": "nook"}, true)
		fl.nooks[nook_i]["used"] = true
		nook_i += 1
	# --- clearings ranked by distance to the straight line spawn -> exit (off the beaten path first)
	var ranked: Array = side.duplicate()
	var ex: int = fl.entry.x
	var ey: int = fl.entry.y
	ranked.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
		var dp: int = _line_d2(int(p["cx"]), int(p["cy"]), ex, ey, hx, hy)
		var dq: int = _line_d2(int(q["cx"]), int(q["cy"]), ex, ey, hx, hy)
		if dp != dq:
			return dp > dq
		return int(p["id"]) < int(q["id"]))
	var pool: Array = ranked if not ranked.is_empty() else fl.clearings
	# --- lake chest on the shore of the biggest pond
	var lake: String = str(spec.get("lake", ""))
	if lake != "":
		var best_pond: Dictionary = {}
		var best_cells: int = 0
		for cl in fl.clearings:
			if cl.has("pond") and int((cl["pond"] as Vector3i).z) > best_cells:
				best_cells = int((cl["pond"] as Vector3i).z)
				best_pond = cl
		if not best_pond.is_empty():
			var shore: Array = []
			for y in range(BORDER, fl.h - BORDER):
				for x in range(BORDER, fl.w - BORDER):
					var i: int = y * fl.w + x
					var g: int = fl.ground[i]
					if g == G_WALL or g == G_POND or fl.trail[i] == 1 or fl.occupied[i] == 1 or fl.blocked[i] == 1:
						continue
					var by_pond: bool = false
					for o in DIRS:
						if x + o.x >= 0 and y + o.y >= 0 and x + o.x < fl.w and y + o.y < fl.h and fl.ground[(y + o.y) * fl.w + x + o.x] == G_POND:
							by_pond = true
					if not by_pond or not can_block(fl, x, y):
						continue
					if _d2(x, y, int((best_pond["pond"] as Vector3i).x), int((best_pond["pond"] as Vector3i).y)) > 260:
						continue
					if _d2(x, y, ex, ey) < 150:
						continue
					if not _solid_ok(fl, x, y):
						continue
					shore.append(Vector2i(x, y))
			if not shore.is_empty():
				_put(fl, "chest", shore[rng.below(shore.size())], {"tier": lake, "role": "lake", "lock": 1}, true)
	# --- the ordinary chest in a side clearing (unless it sits in a nook)
	if not bool(spec["nook_main"]):
		var placed_main: bool = false
		for ti in 6:
			var cl2: Dictionary = pool[(ti + rng.below(pool.size())) % pool.size()]
			var cells2: Array = _cells_of(fl, cl2, true, ex, ey, 120, true)
			if cells2.is_empty():
				cells2 = _cells_of(fl, cl2, false, ex, ey, 120, true)
			if not cells2.is_empty():
				_put(fl, "chest", cells2[rng.below(cells2.size())], {"tier": str(spec["chest_tier"]), "role": "main"}, true)
				placed_main = true
				break
		if not placed_main:
			fl.stats["fail"] = "main_chest"
	# --- enemies: ambush spots first (a tutorial ambush on floors 1-2), then groups of 1..3 in the clearings
	var mix: Dictionary = spec["enemy_mix"] as Dictionary
	var enemies: int = int(spec["enemies"])
	var ambush_left: int = int(spec["ambush"])
	var made_amb: int = 0
	var tries: int = 0
	while made_amb < ambush_left and tries < 60:
		tries += 1
		var cl3: Dictionary = fl.clearings[rng.below(fl.clearings.size())]
		if cl3["kind"] == "entry":
			continue
		var lo: int = 150 if (made_amb == 0 and floor_no <= 2) else 14 * 14
		var hi: int = 420 if (made_amb == 0 and floor_no <= 2) else 0
		var cs: Array = _cells_of(fl, cl3, true, ex, ey, lo, false, hi)
		var cand: Array = []
		for c in cs:
			if _near_trail(fl, c.x, c.y, 2) and not _near_trail(fl, c.x, c.y, 0):
				cand.append(c)
		if cand.is_empty():
			continue
		var spot: Vector2i = cand[rng.below(cand.size())]
		_put(fl, "enemy", spot, {"kind": _kind_of_mix(mix, rng, false), "ambush": 1, "group": -1})
		made_amb += 1
	var ord_left: int = enemies - made_amb
	var group_no: int = 0
	var gtries: int = 0
	var all_cl: Array = fl.clearings
	while ord_left > 0 and gtries < enemies * 6 + 20:
		gtries += 1
		var cl4: Dictionary = all_cl[rng.below(all_cl.size())]
		if cl4["kind"] == "entry":
			continue
		if boss and cl4["kind"] == "exit":
			continue
		var base: Array = _cells_of(fl, cl4, false, ex, ey, 14 * 14)
		if base.is_empty():
			continue
		var count: int = mini(rng.range_i(1, 3), ord_left)
		var kind: String = _kind_of_mix(mix, rng, true)
		var anchor: Vector2i = base[rng.below(base.size())]
		var made: int = 0
		for k in count:
			var sp2: Vector2i = anchor + Vector2i(rng.range_i(-2, 2), rng.range_i(-1, 1))
			if _walkable(fl, sp2.x, sp2.y) and fl.occupied[sp2.y * fl.w + sp2.x] == 0 and fl.blocked[sp2.y * fl.w + sp2.x] == 0 and fl.nookmask[sp2.y * fl.w + sp2.x] == 0 and _d2(sp2.x, sp2.y, ex, ey) >= 14 * 14:
				_put(fl, "enemy", sp2, {"kind": kind, "ambush": 0, "group": group_no})
				made += 1
		if made > 0:
			ord_left -= made
			group_no += 1
	# --- critters (lysesvamp): flee-type glow critters, singly in clearings
	var crit_left: int = int(spec["critters"])
	var ctries: int = 0
	while crit_left > 0 and ctries < 40:
		ctries += 1
		var cl5: Dictionary = fl.clearings[rng.below(fl.clearings.size())]
		var cs5: Array = _cells_of(fl, cl5, false, ex, ey, 100)
		if cs5.is_empty():
			continue
		_put(fl, "enemy", cs5[rng.below(cs5.size())], {"kind": "lysesvamp", "ambush": 0, "critter": 1, "group": -2})
		crit_left -= 1
	# --- resource nodes: solid, on the clearing edge (ore along the walls)
	var node_kinds: Array = (spec["nodes"] as Dictionary).keys()
	node_kinds.sort()
	for nk in node_kinds:
		for k in int((spec["nodes"] as Dictionary)[nk]):
			for attempt in 6:
				var cl6: Dictionary = pool[rng.below(pool.size())]
				var cs6: Array = _cells_of(fl, cl6, true, ex, ey, 30, true)
				if cs6.is_empty():
					continue
				_put(fl, "node", cs6[rng.below(cs6.size())], {"kind": str(nk)}, true)
				break
	# --- glow patches: a 3x3 patch of glow floor, one light (up to lights_max), a glowmush decor cell
	var lights: int = 0
	for k in int(spec["glow"]):
		var cg: Vector2i = Vector2i(-1, -1)
		for attempt in 5:
			var cl7: Dictionary = fl.clearings[rng.below(fl.clearings.size())]
			var cs7: Array = _cells_of(fl, cl7, true, ex, ey, 0)
			if not cs7.is_empty():
				cg = cs7[rng.below(cs7.size())]
				break
		if cg.x < 0:
			continue
		var has_light: bool = lights < int(spec["lights_max"])
		_put(fl, "glow", cg, {"light": 1 if has_light else 0})
		if has_light:
			lights += 1
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				var gi: int = (cg.y + oy) * fl.w + cg.x + ox
				if fl.ground[gi] == fl.t_floor and fl.trail[gi] == 0:
					fl.ground[gi] = fl.t_patch
	# --- dig spots
	for k in int(spec["digs"]):
		for attempt in 5:
			var cl8: Dictionary = fl.clearings[rng.below(fl.clearings.size())]
			var cs8: Array = _cells_of(fl, cl8, false, ex, ey, 25)
			if not cs8.is_empty():
				_put(fl, "dig", cs8[rng.below(cs8.size())])
				break
	# --- whispers: on the main route, away from the spawn
	for k in int(spec["whispers"]):
		var cl9: Dictionary = fl.clearings[rng.below(fl.clearings.size())]
		var cs9: Array = _cells_of(fl, cl9, false, ex, ey, 60)
		if cs9.is_empty():
			continue
		_put(fl, "whisper", cs9[rng.below(cs9.size())], {"n": k})
	# --- other anchors (edge / glow places)
	for an2 in (spec["anchors"] as Array):
		var pl: String = str((an2 as Dictionary).get("place", ""))
		if pl == "nook":
			continue
		var an_solid: bool = str(an2["marker"]) in SOLID_MARKERS
		for k in int((an2 as Dictionary).get("count", 1)):
			for attempt in 8:
				var cl10: Dictionary = pool[rng.below(pool.size())]
				var cs10: Array = []
				if pl == "hulen":
					cs10 = _cells_of(fl, xc, false, hx, hy, 12, an_solid, 80)
				else:
					cs10 = _cells_of(fl, cl10, pl == "edge", ex, ey, 40, an_solid)
					if pl == "glow":
						cs10 = cs10.filter(func(c: Vector2i) -> bool: return fl.ground[c.y * fl.w + c.x] == fl.t_patch)
				if cs10.is_empty():
					continue
				_put(fl, "anchor", cs10[rng.below(cs10.size())], {"marker": str(an2["marker"]), "params": str(an2["params"])}, an_solid)
				break


# ------------------------------------------------------------------------------------------------ 7 inner crowns and decor

@warning_ignore("integer_division")
func _place_inner_crowns(fl: Fl, rng) -> void:
	var want: int = int(fl.spec.get("inner_crowns", 0))
	var made: int = 0
	var tries: int = 0
	var cand_cl: Array = []
	for cl in fl.clearings:
		if int(cl["rx"]) >= 3 and int(cl["ry"]) >= 5:
			cand_cl.append(cl)
	if cand_cl.is_empty():
		return
	# a ring of keep-clear cells round every feature
	var keep := PackedByteArray()
	keep.resize(fl.w * fl.h)
	for f in fl.feats:
		for oy in range(-2, 3):
			for ox in range(-2, 3):
				var ni: int = (int(f["y"]) + oy) * fl.w + int(f["x"]) + ox
				if ni >= 0 and ni < fl.w * fl.h:
					keep[ni] = 1
	while made < want and tries < 40 * maxi(1, want):
		tries += 1
		var cl2: Dictionary = cand_cl[rng.below(cand_cl.size())]
		var size_m: bool = rng.below(100) < 35 and int(cl2["rx"]) >= 4
		var rr: int = 2 if size_m else 1
		var x: int = int(cl2["cx"]) + rng.range_i(-int(cl2["rx"]) + rr + 1, int(cl2["rx"]) - rr - 1)
		var y: int = int(cl2["cy"]) + rng.range_i(-int(cl2["ry"]) + rr + 1, int(cl2["ry"]) - rr - 1)
		var cells: Array[Vector2i] = []
		var ok: bool = true
		for dy in range(-rr, rr + 1):
			for dx in range(-rr, rr + 1):
				# S = 3 x 3 block (collider radius 130 + body 25 px reaches the diagonal cell centres), M = diamond of radius 2 (collider 175 + 25 reaches the axis tips)
				if size_m and absi(dx) + absi(dy) > 2:
					continue
				var c := Vector2i(x + dx, y + dy)
				if c.x < BORDER or c.y < BORDER or c.x >= fl.w - BORDER or c.y >= fl.h - BORDER:
					ok = false
					continue
				var ci: int = c.y * fl.w + c.x
				if fl.ground[ci] == G_WALL or fl.ground[ci] == G_POND or fl.trail[ci] == 1 or fl.occupied[ci] == 1 or fl.blocked[ci] == 1 or keep[ci] == 1:
					ok = false
				cells.append(c)
		if not ok:
			continue
		# the crown disc (the visual) must not hide a feature
		var cls_i: int = 1 if size_m else 0
		for f2 in fl.feats:
			if crown_covers(cls_i, x, y, int(f2["x"]), int(f2["y"])):
				ok = false
				break
		if not ok:
			continue
		# place cell by cell with the neck test, undo when one fails
		var placed: Array[Vector2i] = []
		for c2 in cells:
			if can_block(fl, c2.x, c2.y):
				fl.blocked[c2.y * fl.w + c2.x] = 1
				placed.append(c2)
			else:
				ok = false
				break
		if not ok:
			for c3 in placed:
				fl.blocked[c3.y * fl.w + c3.x] = 0
			continue
		fl.decor[y * fl.w + x] = D_ICROWN_M if size_m else D_ICROWN_S
		made += 1
	fl.stats["inner_crowns"] = made


@warning_ignore("integer_division")
func _place_decor(fl: Fl, rng) -> void:
	var w: int = fl.w
	var rocks: int = 0
	var bushes: int = 0
	var shrooms: int = 0
	var lilies: int = 0
	fl.near_feat = PackedByteArray()
	fl.near_feat.resize(fl.w * fl.h)
	for f in fl.feats:
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				var ni: int = (int(f["y"]) + oy) * w + int(f["x"]) + ox
				if ni >= 0 and ni < fl.w * fl.h:
					fl.near_feat[ni] = 1
	for y in range(BORDER, fl.h - BORDER):
		for x in range(BORDER, w - BORDER):
			var i: int = y * w + x
			var g: int = fl.ground[i]
			if g == G_POND:
				if rng.below(1000) < 70 and fl.decor[i] == 0:
					fl.decor[i] = D_LILY
					lilies += 1
				continue
			if g == G_WALL or fl.trail[i] == 1 or fl.occupied[i] == 1 or fl.near_feat[i] == 1 or fl.decor[i] != 0:
				continue
			if _d2(x, y, fl.entry.x, fl.entry.y) < 20 or _d2(x, y, fl.exit_cell.x, fl.exit_cell.y) < 20:
				continue
			var edge: bool = not _walkable(fl, x - 1, y) or not _walkable(fl, x + 1, y) or not _walkable(fl, x, y - 1) or not _walkable(fl, x, y + 1)
			var r: int = rng.below(1000)
			if fl.blocked[i] == 1:
				continue
			if r < 9 and can_block(fl, x, y):
				fl.decor[i] = D_ROCK
				fl.blocked[i] = 1
				rocks += 1
			elif r < 9 + 26:
				fl.decor[i] = D_BUSH
				bushes += 1
			elif g == fl.t_patch and r < 9 + 26 + 120:
				fl.decor[i] = D_SHROOM
				shrooms += 1
			elif edge and r < 9 + 26 + 120 + 20:
				fl.decor[i] = D_BUSH
				bushes += 1
	fl.stats["rocks"] = rocks
	fl.stats["bushes"] = bushes
	fl.stats["shrooms"] = shrooms
	fl.stats["lilies"] = lilies


# ------------------------------------------------------------------------------------------------ 8 validate

func feature_reachable(fl: Fl, dist: PackedInt32Array, f: Dictionary) -> bool:
	var x: int = f["x"]
	var y: int = f["y"]
	if dist[y * fl.w + x] >= 0:
		return true
	for o in DIRS:
		var nx: int = x + o.x
		var ny: int = y + o.y
		if nx >= 0 and ny >= 0 and nx < fl.w and ny < fl.h and dist[ny * fl.w + nx] >= 0:
			return true
	return false


@warning_ignore("integer_division")
func _validate(fl: Fl) -> bool:
	var spec: Dictionary = fl.spec
	var dist: PackedInt32Array = _bfs(fl, fl.entry)
	var xi: int = fl.exit_cell.y * fl.w + fl.exit_cell.x
	if dist[xi] < 0:
		fl.stats["fail"] = "exit"
		return false
	for f in fl.feats:
		if not feature_reachable(fl, dist, f):
			fl.stats["fail"] = "feature_" + String(f["t"])
			return false
	var counts: Dictionary = {}
	for f in fl.feats:
		var key: String = String(f["t"])
		if f.has("role"):
			key += "_" + String(f["role"])
		if f["t"] == "enemy":
			key += "_amb" if int(f.get("ambush", 0)) == 1 else ("_crit" if int(f.get("critter", 0)) == 1 else "")
		counts[key] = int(counts.get(key, 0)) + 1
	fl.stats["counts"] = counts
	# Story witnesses are required, unlike optional forage/decor anchors. A
	# crowded exit pocket must retry the layout rather than silently lose its NPC.
	var expected_keepers := 0
	for anchor in spec["anchors"]:
		if str(anchor.get("marker", "")) == "hulen_keeper":
			expected_keepers += int(anchor.get("count", 1))
	var keepers := 0
	for feature in fl.feats:
		if str(feature.get("t", "")) == "anchor" and str(feature.get("marker", "")) == "hulen_keeper":
			keepers += 1
	if keepers != expected_keepers:
		fl.stats["fail"] = "required_witness"
		return false
	if bool(spec["stone"]) and int(counts.get("runestone", 0)) != 1:
		fl.stats["fail"] = "runestone"
		return false
	if int(counts.get("up", 0)) != 1:
		fl.stats["fail"] = "up"
		return false
	if int(counts.get("spawn_rune", 0)) != (1 if bool(spec["stone"]) else 0):
		fl.stats["fail"] = "spawn_rune"
		return false
	if int(counts.get("home", 0)) != (0 if bool(spec["hulen"]) else 1):
		fl.stats["fail"] = "home"
		return false
	if bool(spec["boss"]) and (int(counts.get("boss", 0)) != 1 or int(counts.get("chest_boss", 0)) != 1):
		fl.stats["fail"] = "boss"
		return false
	var want_chests: int = 1 if not bool(spec["nook_main"]) else 0
	if int(counts.get("chest_main", 0)) != want_chests or int(counts.get("chest_nook", 0)) != (1 if bool(spec["nook_main"]) else 0):
		fl.stats["fail"] = "main_chest"
		return false
	if str(spec["lake"]) != "" and int(counts.get("chest_lake", 0)) != 1:
		fl.stats["fail"] = "lake_chest"
		return false
	if int(counts.get("spot", 0)) != (spec["spots"] as Array).size():
		fl.stats["fail"] = "spots"
		return false
	var amb_want: int = int(spec["ambush"])
	# MERGED ADDENDUM (D1 task "two hard gates"): the independent verifier found 3 violations in 10 008 floors of the seed range 1000..1833 (f1 i1550, f2 i1396, f2 i1526): both rules were only
	# soft / measured at a different cell than the verifier uses.  They are HARD in every attempt and use the verifier's own formulas (spawn = the entry cell).
	for hf in fl.feats:
		if str(hf["t"]) == "hulen":
			var hdist: int = absi(int(hf["x"]) - fl.entry.x) + absi(int(hf["y"]) - fl.entry.y)
			if hdist < int(spec["w"]) * 2 / 5:
				fl.stats["fail"] = "hulen_far"
				return false
	if int(spec["floor"]) <= 2 and amb_want > 0:
		var tut_ok: bool = false
		for tf in fl.feats:
			if str(tf["t"]) == "enemy" and int(tf.get("ambush", 0)) == 1:
				var tdx: int = int(tf["x"]) - fl.entry.x
				var tdy: int = int(tf["y"]) - fl.entry.y
				var tq: int = 3 * tdx * tdx + tdy * tdy
				if tq >= 150 and tq <= 420:
					tut_ok = true
		if not tut_ok:
			fl.stats["fail"] = "tutorial_ambush"
			return false
	var soft: bool = fl.attempts <= 4
	var enemy_total: int = int(counts.get("enemy", 0)) + int(counts.get("enemy_amb", 0))
	if soft and (enemy_total < int(spec["enemies"]) or int(counts.get("enemy_amb", 0)) < amb_want or int(counts.get("enemy_crit", 0)) < int(spec["critters"])):
		fl.stats["fail"] = "sparse_enemies"
		return false
	for hk in (spec["hard_nodes"] as Array):
		var want_hard: int = int((spec["nodes"] as Dictionary).get(str(hk), 0))
		var have_hard: int = 0
		for f3 in fl.feats:
			if str(f3["t"]) == "node" and str(f3.get("kind", "")) == str(hk):
				have_hard += 1
		if have_hard != want_hard:
			fl.stats["fail"] = "hard_node_" + str(hk)
			return false
	var nodes_total: int = 0
	for nk in (spec["nodes"] as Dictionary):
		nodes_total += int((spec["nodes"] as Dictionary)[nk])
	if soft and (int(counts.get("node", 0)) < maxi(1, nodes_total - 1) or int(counts.get("dig", 0)) < int(spec["digs"]) or int(counts.get("glow", 0)) < int(spec["glow"]) * 3 / 4):
		fl.stats["fail"] = "sparse_features"
		return false
	var walk: int = 0
	var reach: int = 0
	for i in fl.w * fl.h:
		var g: int = fl.ground[i]
		if g != G_WALL and g != G_POND and fl.blocked[i] == 0:
			walk += 1
			if dist[i] >= 0:
				reach += 1
	fl.stats["walkable"] = walk
	if soft and (walk * 100 < fl.w * fl.h * int(spec["min_walk_pct"]) or int(fl.stats.get("sites", 0)) < int(spec["min_sites"])):
		fl.stats["fail"] = "sparse"
		return false
	if walk * 100 > fl.w * fl.h * int(spec["max_walk_pct"]) and soft:
		fl.stats["fail"] = "too_open"
		return false
	fl.stats["reachable"] = reach
	fl.stats["route"] = dist[xi]
	fl.stats["manhattan"] = absi(fl.exit_cell.x - fl.entry.x) + absi(fl.exit_cell.y - fl.entry.y)
	if reach * 100 < walk * 98:
		fl.stats["fail"] = "islands"
		return false
	return true


# ------------------------------------------------------------------------------------------------ 9 mirror

## Deterministic mirror of the finished floor (two bits of the stream): the route is not always west -> east, start not always left.
func _mirror(fl: Fl, rng) -> void:
	fl.flip_x = rng.below(2) == 1
	fl.flip_y = rng.below(2) == 1
	if not fl.flip_x and not fl.flip_y:
		return
	var w: int = fl.w
	var h: int = fl.h
	for nm in ["ground", "trail", "blocked", "occupied", "decor", "near_feat", "nookmask"]:
		var src: PackedByteArray = fl.get(nm)
		var dst := PackedByteArray()
		dst.resize(w * h)
		for y in h:
			var sy: int = (h - 1 - y) if fl.flip_y else y
			for x in w:
				var sx: int = (w - 1 - x) if fl.flip_x else x
				dst[y * w + x] = src[sy * w + sx]
		fl.set(nm, dst)
	for f in fl.feats:
		if fl.flip_x:
			f["x"] = w - 1 - int(f["x"])
		if fl.flip_y:
			f["y"] = h - 1 - int(f["y"])
	if fl.flip_x:
		fl.entry.x = w - 1 - fl.entry.x
		fl.exit_cell.x = w - 1 - fl.exit_cell.x
	if fl.flip_y:
		fl.entry.y = h - 1 - fl.entry.y
		fl.exit_cell.y = h - 1 - fl.exit_cell.y
	for nk in fl.nooks:
		var p: Vector2i = nk["pocket"]
		var m: Vector2i = nk["mouth"]
		if fl.flip_x:
			p.x = w - 1 - p.x
			m.x = w - 1 - m.x
		if fl.flip_y:
			p.y = h - 1 - p.y
			m.y = h - 1 - m.y
		nk["pocket"] = p
		nk["mouth"] = m
	for cl in fl.clearings:
		if fl.flip_x:
			cl["cx"] = w - 1 - int(cl["cx"])
		if fl.flip_y:
			cl["cy"] = h - 1 - int(cl["cy"])


func digest(fl: Fl) -> int:
	var h: int = 0x811C9DC5
	for b in fl.ground:
		h = ((h ^ b) * 16777619) & 0xFFFFFFFF
	for b in fl.decor:
		h = ((h ^ b) * 16777619) & 0xFFFFFFFF
	for f in fl.feats:
		for v in [f["x"], f["y"], String(f["t"]).length(), String(f.get("tier", f.get("kind", f.get("spot", "")))).length()]:
			h = ((h ^ (int(v) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
	h = ((h ^ fl.attempts) * 16777619) & 0xFFFFFFFF
	h = ((h ^ (1 if fl.flip_x else 0) ^ (2 if fl.flip_y else 0)) * 16777619) & 0xFFFFFFFF
	return h

## Single scene-free entry point for serial generation and prefetch workers.
## No LuaRuntime, scene nodes or mutable game services are accessed here.
static func build_text(cfg: Dictionary, floor_number: int, seed_value: int, context: Dictionary = {}) -> Dictionary:
	var spec := DungeonSpec.spec_for(cfg,floor_number)
	if spec.is_empty(): return {"ok":false,"text":"","error":"unknown_floor"}
	var generator := DungeonGen.new()
	var floor_data := generator.generate(seed_value,spec,int(LuaData.dict(cfg.get("seed",{})).get("retry_max",8)))
	if not bool(floor_data.stats.get("ok",false)): return {"ok":false,"text":"","error":str(floor_data.stats.get("fail","generation_failed"))}
	var ctx := context.duplicate(true)
	var prefix := str(LuaData.dict(cfg.get("hub",{})).get("floor_prefix","moerkeskoven_f"))
	ctx.merge({"prev_id":prefix+str(floor_number-1),"next_id":prefix+str(floor_number+1),"gen_version":int(cfg.get("gen_version",1)),"spec_hash":DungeonSpec.spec_hash(cfg),"seed_text":str(seed_value)},false)
	var exporter: Script = load("res://scripts/dungeon/gen/dungeon_export.gd")
	var exported: Dictionary = exporter.build(floor_data,cfg,ctx)
	exported["ok"] = true
	exported["crowns"] = exported.get("rim_crowns",[])
	exported.stats["attempts"] = floor_data.attempts
	exported.stats["fallback"] = bool(floor_data.stats.get("fallback",false))
	return exported
