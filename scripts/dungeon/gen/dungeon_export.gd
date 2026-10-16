class_name DungeonExport
extends RefCounted
## DESIGNER A prototype: turns a generated floor (dg2_gen.gd Fl) into standard AreaMap TEXT (what a hand-written .map file holds), padded with void
## and covered with canopy crowns. One object char per distinct marker / prop parameter set; per-instance data (uid, seeds) is derived from the CELL
## (y * width + x) and the header extras @floor @day @seed by the handlers, so the text stays small and needs no Private-Use chars.
##
## ground chars: m n o . forest floor, g glow floor, p moss path, ~ pond, c cave floor, x crystal floor, W wall rim (depth `wall_depth` from the floor), # void.
## header extras (AreaMap.extra): floor band day seed gen spec flip

const Gen := preload("res://scripts/dungeon/gen/dungeon_gen.gd")

const POOL := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!$%&*+-/:;<>?^_|~"
## walkable overlap a crown may have (cells of floor under its disc) per class S / M / L
const WALK_OVERLAP: Array[int] = [2, 3, 4]
const CROWN_PROP: Array[String] = ["crown_s_a", "crown_s_b", "crown_m_a", "crown_m_b", "crown_l_a", "crown_l_b"]
## the free-standing (solid) crowns use their own prop ids so props_extra.lua can give them a collider: art = the rim crown of the same size
const CROWN_SOLID: Array[String] = ["crown_s_a_solid", "crown_s_b_solid", "crown_m_a_solid", "crown_m_b_solid"]


static func floor_id(prefix: String, n: int) -> StringName:
	return StringName("%s%d" % [prefix, n])


## Builds the text. `ctx`: prefix, prev_id, next_id, day, world_seed (decimal text), gen_version, spec_hash, wall_depth, pad_x, pad_n, pad_s.
## Returns {text, stats, crowns (Array of Vector3i x,y,code), w, h, ox, oy}.
@warning_ignore("integer_division")
static func build(fl, cfg: Dictionary, ctx: Dictionary) -> Dictionary:
	var rim: Dictionary = cfg.get("rim", {}) as Dictionary
	var is_iso: bool = str(ctx.get("projection", "ortho")) == "iso"
	var wall_depth: int = int(ctx.get("wall_depth", rim.get("wall_depth_iso", 0) if is_iso else rim.get("wall_depth", 1)))
	var pad_x: int = int(ctx.get("pad_x", rim.get("pad_x", 4)))
	var pad_n: int = int(ctx.get("pad_n", rim.get("pad_n", 3)))
	var pad_s: int = int(ctx.get("pad_s", rim.get("pad_s", 9)))
	var spec: Dictionary = fl.spec
	var floor_no: int = int(spec["floor"])
	var w: int = fl.w + 2 * pad_x
	var h: int = fl.h + pad_n + pad_s
	var ox: int = pad_x
	var oy: int = pad_n
	var hub: Dictionary = cfg.get("hub", {}) as Dictionary
	var prefix: String = str(hub.get("floor_prefix", "moerkeskoven_f"))
	var band: Dictionary = (cfg.get("bands", {}) as Dictionary).get(str(spec["band"]), {}) as Dictionary
	var flags: Dictionary = cfg.get("flags", {}) as Dictionary
	var boss_flag: String = str(flags.get("boss_clear", "dg_boss_clear"))
	# ---- distance (Chebyshev) of every non-walkable cell to the nearest walkable one: wall rim vs void
	var walk := PackedByteArray()
	walk.resize(w * h)
	for y in fl.h:
		for x in fl.w:
			var g: int = fl.ground[y * fl.w + x]
			if g != Gen.G_WALL:
				walk[(y + oy) * w + x + ox] = 1
	var near: PackedByteArray = _near(walk, w, h)
	var iso_map: bool = str(ctx.get("projection", "ortho")) == "iso"
	var grows := PackedStringArray()
	var buf := PackedByteArray()
	buf.resize(w)
	var floor_cells: int = 0
	var wall_cells: int = 0
	for y in h:
		for x in w:
			var i: int = y * w + x
			var code: int = 35   # '#'
			if walk[i] == 1:
				code = fl.ground[(y - oy) * fl.w + (x - ox)]
				if iso_map:
					code = 109 if code == 99 else (103 if code == 120 else code)    # iso reads c as cobble: cave floor -> forest floor, crystal floor -> glow floor
				floor_cells += 1
			elif int(near[i]) <= wall_depth:
				code = 87        # 'W'
				wall_cells += 1
			buf[x] = code
		grows.append(buf.get_string_from_ascii())
	# ---- object chars: one char per distinct (type + params) key, allocated from POOL in first-use order
	var char_of: Dictionary = {}       # key -> char
	var decl_marker: Array = []        # [char, type, params text]
	var decl_prop: Array = []          # [char, prop id]
	var pool_i: int = 0
	var ocodes: Array = []
	ocodes.resize(w * h)
	ocodes.fill(".")
	var next_id: String = str(ctx.get("next_id", ""))
	var prev_id: String = str(ctx.get("prev_id", ""))
	var tier: int = int(spec["tier"])
	var hulen_type: String = str(cfg.get("hulen_marker", "warp"))
	var markers_n: int = 0
	var f_by_cell: Dictionary = {}
	for f in fl.feats:
		var t: String = str(f["t"])
		var cell: int = (int(f["y"]) + oy) * w + int(f["x"]) + ox
		var mtype: String = ""
		var params: String = ""
		match t:
			"spawn":
				ocodes[cell] = "@"
				markers_n += 1
				continue
			"spawn_down":
				mtype = "spawn"
				params = "name=from_down"
			"hulen":
				if hulen_type == "hulen":
					mtype = "hulen"
					params = "to=%s floor=%d" % [next_id, floor_no + 1]
					if bool(f.get("sealed", false)):
						params += " sealed_by=" + str(spec["boss_kind"])
				else:
					mtype = "warp"
					params = "to=%s spawn=default label=%s prop=cave_ring r=0" % [next_id, str((((cfg.get("bands", {}) as Dictionary).get(_band_of(cfg, floor_no + 1), {})) as Dictionary).get("name_key", str(band.get("name_key", "ZONE_DARK_FOREST"))))]
					if bool(f.get("sealed", false)):
						params += " when=flag:" + boss_flag
			"home":
				if hulen_type == "hulen":
					mtype = "hulen"
					params = "to=%s floor=0 home_rope=1" % str(hub.get("area", "moerkeskoven"))
					if bool(f.get("sealed", false)):
						params += " sealed_by=" + str(spec["boss_kind"])
				else:
					mtype = "warp"
					params = "to=%s spawn=from_floor label=%s prop=home_rope r=0" % [str(hub.get("area", "moerkeskoven")), str(hub.get("title_key", "ZONE_FOREST_EDGE"))]
					if bool(f.get("sealed", false)):
						params += " when=flag:" + boss_flag
			"spawn_rune":
				mtype = "spawn"
				params = "name=rune"
			"up":
				mtype = "warp"
				if floor_no == 1:
					params = "to=%s spawn=from_floor label=%s prop=cave_ring_up r=0" % [str(hub.get("area", "moerkeskoven")), str(hub.get("title_key", "ZONE_FOREST_EDGE"))]
				else:
					params = "to=%s spawn=from_down label=%s prop=cave_ring_up r=0" % [prev_id, str((((cfg.get("bands", {}) as Dictionary).get(_band_of(cfg, floor_no - 1), {})) as Dictionary).get("name_key", "ZONE_DARK_FOREST"))]
			"runestone":
				mtype = "runestone"
				params = "id=rune_f%d waypoint=1" % floor_no
			"chest":
				mtype = "chest"
				params = "tier=%s role=%s" % [str(f["tier"]), str(f["role"])]
				if str(f["role"]) == "nook":
					params += " hidden=1"
				if int(f.get("lock", 0)) == 1:
					params += " lock=" + str(cfg.get("key_item", "ugle_noegle"))
				if bool(f.get("sealed", false)):
					params += " when=flag:" + boss_flag + " boss=" + str(f["boss"])
			"dig":
				mtype = "dig_spot"
				params = ""
			"spot":
				mtype = "unique_spot"
				params = "id=%s" % str(f["spot"])
			"enemy":
				mtype = "enemy"
				params = "kind=%s tier=%d" % [str(f["kind"]), tier]
				if int(f.get("ambush", 0)) == 1:
					params += " ambush=1"
				if int(f.get("critter", 0)) == 1:
					params += " critter=1"
			"boss":
				mtype = "enemy"
				params = "kind=%s tier=%d boss=1 adds=%d" % [str(f["kind"]), tier, int(f["adds"])]
			"node":
				mtype = "node"
				params = "kind=%s" % str(f["kind"])
			"glow":
				if int(f.get("light", 0)) == 1:
					mtype = "light"
					params = "kind=glow r=170 h=30"
				else:
					continue
			"whisper":
				mtype = "whisper"
				var wl: Array = band.get("whispers", []) as Array
				var wn: int = mini(int(f["n"]), maxi(0, wl.size() - 1))
				params = "text=%s r=2" % (str((wl[wn] as Dictionary)["text_key"]) if not wl.is_empty() else "DUNGEON_WHISPER_%s_%d" % [str(spec["band"]).to_upper(), int(f["n"]) + 1])
			"anchor":
				mtype = str(f["marker"])
				params = str(f["params"])
			_:
				continue
		var key: String = "m|" + mtype + "|" + params
		if not char_of.has(key):
			char_of[key] = POOL[pool_i]
			pool_i += 1
			decl_marker.append([char_of[key], mtype, params])
		ocodes[cell] = char_of[key]
		markers_n += 1
	# ---- decor props from the generator (rocks, bushes, mushrooms, lilies) and the inner crowns
	var decor_props: Dictionary = {Gen.D_ROCK: "rock_dark", Gen.D_BUSH: "bush_forest", Gen.D_LILY: "pond_lily", Gen.D_SHROOM: "glowmush_teal"}
	var props_n: int = 0
	var inner_n: int = 0
	var inner_codes: Array = []
	for y in fl.h:
		for x in fl.w:
			var d: int = fl.decor[y * fl.w + x]
			if d == 0:
				continue
			var cell2: int = (y + oy) * w + x + ox
			if ocodes[cell2] != ".":
				continue
			var pid: String = ""
			if d == Gen.D_ICROWN_S or d == Gen.D_ICROWN_M:
				var cls0: int = 0 if d == Gen.D_ICROWN_S else 1
				pid = CROWN_SOLID[cls0 * 2 + (((x * 31 + y * 17) >> 2) & 1)]
				inner_n += 1
				inner_codes.append(Vector3i(x + ox, y + oy, cls0))
			else:
				pid = str(decor_props.get(d, ""))
			if pid == "":
				continue
			var pk: String = "p|" + pid
			if not char_of.has(pk):
				char_of[pk] = POOL[pool_i]
				pool_i += 1
				decl_prop.append([char_of[pk], pid])
			ocodes[cell2] = char_of[pk]
			props_n += 1
	# ---- rim crowns on the void / wall cells outside the floor
	var protect := PackedByteArray()
	protect.resize(w * h)
	for f2 in fl.feats:
		if str(f2["t"]) == "glow" and int(f2.get("light", 0)) == 0:
			pass
		for oy2 in range(-1, 2):
			for ox2 in range(-1, 2):
				var pi: int = (int(f2["y"]) + oy + oy2) * w + int(f2["x"]) + ox + ox2
				if pi >= 0 and pi < w * h:
					protect[pi] = 1
	var hseed: int = (int(fl.seed_value) ^ (floor_no * 2654435)) & 0x7FFFFFFF
	var rim_crowns: Array = place_rim_crowns(w, h, walk, near, protect, hseed, inner_codes) if bool(ctx.get("crowns", true)) else []
	for c in rim_crowns:
		var cell3: int = c.y * w + c.x
		if ocodes[cell3] != ".":
			continue
		var pid2: String = CROWN_PROP[c.z]
		var pk2: String = "p|" + pid2
		if not char_of.has(pk2):
			char_of[pk2] = POOL[pool_i]
			pool_i += 1
			decl_prop.append([char_of[pk2], pid2])
		ocodes[cell3] = char_of[pk2]
		props_n += 1
	# ---- text
	var lines := PackedStringArray()
	lines.append("# generated floor %s by the dungeon generator v%s (do not edit: the same seed gives the same text)" % [floor_id(prefix, floor_no), str(ctx.get("gen_version", 1))])
	lines.append("@id %s" % floor_id(prefix, floor_no))
	lines.append("@title %s" % str(band.get("name_key", "ZONE_DARK_FOREST")))
	lines.append("@projection %s" % str(ctx.get("projection", "ortho")))
	lines.append("@ambient %s" % str(band.get("ambient", "forest")))
	lines.append("@theme %s" % str(band.get("theme", "forest")))
	lines.append("@zone %s" % str(band.get("zone", "dark_forest")))
	lines.append("@depth %d" % floor_no)
	lines.append("@flight false")
	lines.append("@music %s" % str(band.get("music", "forest_theme")))
	lines.append("@floor %d" % floor_no)
	lines.append("@band %s" % str(spec["band"]))
	lines.append("@day %d" % int(ctx.get("day", 0)))
	lines.append("@seed %s" % str(ctx.get("seed_text", str(fl.seed_value))))
	lines.append("@gen %s" % str(ctx.get("gen_version", 1)))
	lines.append("@spec %s" % str(ctx.get("spec_hash", "0")))
	lines.append("@flip %d %d" % [1 if fl.flip_x else 0, 1 if fl.flip_y else 0])
	for d1 in decl_prop:
		lines.append("@prop %s %s" % [d1[0], d1[1]])
	for d2 in decl_marker:
		lines.append(("@marker %s %s %s" % [d2[0], d2[1], d2[2]]).strip_edges())
	lines.append("@ground")
	lines.append_array(grows)
	lines.append("@objects")
	for y in h:
		var s: String = ""
		for x in w:
			s += str(ocodes[y * w + x])
		lines.append(s)
	var text: String = "\n".join(lines) + "\n"
	var stats: Dictionary = {"w": w, "h": h, "floor_cells": floor_cells, "wall_cells": wall_cells, "props": props_n, "markers": markers_n, "rim_crowns": rim_crowns.size(),
		"inner_crowns": inner_n, "chars_used": pool_i}
	return {"text": text, "stats": stats, "rim_crowns": rim_crowns, "inner": inner_codes, "w": w, "h": h, "ox": ox, "oy": oy}


static func _band_of(cfg: Dictionary, floor_no: int) -> String:
	for f in (cfg.get("floors", []) as Array):
		if int((f as Dictionary).get("n", 0)) == floor_no:
			return str((f as Dictionary).get("band", "skovkant"))
	return "skovkant"


## Chebyshev distance (capped at 40) of every NON-walkable cell to the nearest walkable cell; walkable cells are 0.
static func _near(walk: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var near := PackedByteArray()
	near.resize(w * h)
	for i in w * h:
		near[i] = 0 if walk[i] == 1 else 40
	for y in h:
		for x in w:
			var i2: int = y * w + x
			var v: int = near[i2]
			if x > 0:
				v = mini(v, near[i2 - 1] + 1)
			if y > 0:
				v = mini(v, near[i2 - w] + 1)
				if x > 0:
					v = mini(v, near[i2 - w - 1] + 1)
				if x < w - 1:
					v = mini(v, near[i2 - w + 1] + 1)
			near[i2] = mini(v, 40)
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i3: int = y * w + x
			var v2: int = near[i3]
			if x < w - 1:
				v2 = mini(v2, near[i3 + 1] + 1)
			if y < h - 1:
				v2 = mini(v2, near[i3 + w] + 1)
				if x < w - 1:
					v2 = mini(v2, near[i3 + w + 1] + 1)
				if x > 0:
					v2 = mini(v2, near[i3 + w - 1] + 1)
			near[i3] = mini(v2, 40)
	return near


## The canopy ring. Candidates are cells outside the floor at 1..11 cells from it, thinned by a hash (about 1 in 5), taken nearest first. A crown of
## the largest class that fits is accepted when (a) at most WALK_OVERLAP floor cell centres lie under its disc, (b) no protected cell (a feature or
## its ring) lies under it, (c) at least 35 percent of the non-floor cells under it are not yet covered by an earlier crown.
@warning_ignore("integer_division")
static func place_rim_crowns(w: int, h: int, walk: PackedByteArray, near: PackedByteArray, protect: PackedByteArray, hseed: int, inner: Array) -> Array:
	# row prefix sums of the two masks
	var pw := PackedInt32Array()
	var pp := PackedInt32Array()
	pw.resize((w + 1) * h)
	pp.resize((w + 1) * h)
	for y in h:
		var a: int = 0
		var b: int = 0
		for x in w:
			a += walk[y * w + x]
			b += protect[y * w + x]
			pw[y * (w + 1) + x + 1] = a
			pp[y * (w + 1) + x + 1] = b
	var covered := PackedByteArray()
	covered.resize(w * h)
	var out: Array = []
	# inner crowns count as covered ground too (their discs are drawn there already)
	# candidate buckets by distance
	var buckets: Array = []
	for k in 12:
		buckets.append(PackedInt32Array())
	for y in h:
		for x in w:
			var i: int = y * w + x
			if walk[i] == 1:
				continue
			var d: int = near[i]
			if d < 1 or d > 11:
				continue
			var hv: int = ((x * 73856093) ^ (y * 19349663) ^ hseed) & 0x7FFFFFFF
			if hv % 5 != 0:
				continue
			buckets[d].append(i)
	for d2 in range(1, 12):
		for i2 in buckets[d2]:
			var x2: int = i2 % w
			var y2: int = i2 / w
			var cls_max: int = 2 if d2 >= 6 else (1 if d2 >= 3 else 0)
			for cls in range(cls_max, -1, -1):
				var rows: Array = Gen.crown_rows(cls)
				var walk_ov: int = 0
				var prot_ov: int = 0
				var void_total: int = 0
				var void_new: int = 0
				for r in rows:
					var yy: int = y2 + r.x
					if yy < 0 or yy >= h:
						continue
					var xl: int = maxi(x2 + r.y, 0)
					var xh: int = mini(x2 + r.z, w - 1)
					if xh < xl:
						continue
					walk_ov += pw[yy * (w + 1) + xh + 1] - pw[yy * (w + 1) + xl]
					prot_ov += pp[yy * (w + 1) + xh + 1] - pp[yy * (w + 1) + xl]
					if walk_ov > WALK_OVERLAP[cls] or prot_ov > 0:
						break
					for xx in range(xl, xh + 1):
						var ci: int = yy * w + xx
						if walk[ci] == 0:
							void_total += 1
							if covered[ci] == 0:
								void_new += 1
				if walk_ov > WALK_OVERLAP[cls] or prot_ov > 0:
					continue
				if void_total == 0 or void_new * 100 < void_total * 35:
					continue
				for r2 in rows:
					var yy2: int = y2 + r2.x
					if yy2 < 0 or yy2 >= h:
						continue
					for xx2 in range(maxi(x2 + r2.y, 0), mini(x2 + r2.z, w - 1) + 1):
						covered[yy2 * w + xx2] = 1
				var variant: int = ((x2 * 31 + y2 * 17 + hseed) >> 3) & 1
				out.append(Vector3i(x2, y2, cls * 2 + variant))
				break
	return out
