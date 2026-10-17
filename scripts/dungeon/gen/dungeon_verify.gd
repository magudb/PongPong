class_name DungeonVerify
extends RefCounted
## DESIGNER A prototype: the INDEPENDENT verifier of a generated floor. It reads only the AreaMap that AreaMap.parse_text made from the exported text
## (rows, markers, props, extras), never the generator's arrays, and uses its own flood fill. It is what tests/sections/dungeon_gen.gd asserts.
## verify(m, spec, cfg, ctx, T) returns nothing; T is a tally Dictionary {checks: {name: n}, bad: {name: n}, first: {name: detail}} filled in place.

const Gen := preload("res://scripts/dungeon/gen/dungeon_gen.gd")

const WALK := "mnogpcx."
const GROUND_OK := "mnogpcx.~W#"


static func _ok(T: Dictionary, name: String, cond: bool, detail: String = "") -> void:
	var checks: Dictionary = T["checks"]
	checks[name] = int(checks.get(name, 0)) + 1
	if not cond:
		var bad: Dictionary = T["bad"]
		bad[name] = int(bad.get(name, 0)) + 1
		var first: Dictionary = T["first"]
		if not first.has(name):
			first[name] = "[%s] %s" % [str(T.get("tag", "")), detail]


static func _solid_prop(pid: String) -> int:
	# footprint class of the solid props the generator emits: 0 rock (one cell), 1 small solid crown (3 x 3 block), 2 medium solid crown (diamond r 2); -1 = not solid
	match pid:
		"rock_dark":
			return 0
		"crown_s_a_solid", "crown_s_b_solid":
			return 1
		"crown_m_a_solid", "crown_m_b_solid":
			return 2
	return -1


static func _crown_cls(pid: String) -> int:
	match pid:
		"crown_s_a", "crown_s_b", "crown_s_a_solid", "crown_s_b_solid":
			return 0
		"crown_m_a", "crown_m_b", "crown_m_a_solid", "crown_m_b_solid":
			return 1
		"crown_l_a", "crown_l_b":
			return 2
	return -1


@warning_ignore("integer_division")
static func verify(m: AreaMap, spec: Dictionary, cfg: Dictionary, ctx: Dictionary, T: Dictionary) -> void:
	var rim: Dictionary = cfg.get("rim", {}) as Dictionary
	var pad_x: int = int(rim.get("pad_x", 4))
	var pad_n: int = int(rim.get("pad_n", 3))
	var pad_s: int = int(rim.get("pad_s", 9))
	var floor_no: int = int(spec["floor"])
	var hub: Dictionary = cfg.get("hub", {}) as Dictionary
	var prefix: String = str(hub.get("floor_prefix", "moerkeskoven_f"))
	var w: int = m.width
	var h: int = m.height
	_ok(T, "text_parses_without_errors", m.errors.is_empty(), str(m.errors))
	_ok(T, "header_complete", str(m.id) == "%s%d" % [prefix, floor_no] and m.projection == &"ortho" and m.depth == floor_no and not m.flight_allowed
		and m.extra.has("floor") and m.extra.has("band") and m.extra.has("day") and m.extra.has("seed") and m.extra.has("gen") and m.extra.has("spec")
		and str(m.extra["floor"]) == str(floor_no) and str(m.extra["band"]) == str(spec["band"]), "id=%s depth=%d extra=%s" % [m.id, m.depth, str(m.extra.keys())])
	var band: Dictionary = (cfg.get("bands", {}) as Dictionary).get(str(spec["band"]), {}) as Dictionary
	_ok(T, "zone_ambient_music_from_band", str(m.zone) == str(band.get("zone", "")) and str(m.ambient) == str(band.get("ambient", "")) and m.music == str(band.get("music", "")) and m.title == str(band.get("name_key", "")))
	_ok(T, "map_size_is_play_area_plus_padding", w == int(spec["w"]) + 2 * pad_x and h == int(spec["h"]) + pad_n + pad_s, "%dx%d" % [w, h])
	var rows_ok: bool = m.ground.size() == h and m.objects.size() == h
	var chars_ok: bool = true
	if rows_ok:
		for y in h:
			if m.ground[y].length() != w or m.objects[y].length() != w:
				rows_ok = false
			for x in w:
				if not GROUND_OK.contains(m.ground[y][x]):
					chars_ok = false
	_ok(T, "all_rows_have_equal_length", rows_ok)
	_ok(T, "only_declared_ground_chars", chars_ok)
	if not rows_ok:
		return
	# ---- objects: classify every char
	var spawn_cells: Array = []
	var by_type: Dictionary = {}
	var cells_of_type: Dictionary = {}
	var blockers: Dictionary = {}
	var crowns: Array = []                 # {cell, cls, solid}
	var undeclared: int = 0
	var props_n: int = 0
	var markers_n: int = 0
	for y in h:
		var row: String = m.objects[y]
		for x in w:
			var ch: String = row[x]
			if ch == ".":
				continue
			var c := Vector2i(x, y)
			if ch == "@":
				spawn_cells.append(c)
				continue
			if m.props.has(ch):
				props_n += 1
				var pid: String = str(m.props[ch]["prop"])
				var cls: int = _crown_cls(pid)
				if cls >= 0:
					var walk_here: bool = WALK.contains(m.ground[y][x])
					crowns.append({"cell": c, "cls": cls, "walk": walk_here, "pid": pid})
				var sr: int = _solid_prop(pid)
				if sr >= 0 and WALK.contains(m.ground[y][x]):
					for dy in range(-sr, sr + 1):
						for dx in range(-sr, sr + 1):
							if sr == 1 or absi(dx) + absi(dy) <= sr:
								blockers[Vector2i(x + dx, y + dy)] = true
				by_type["prop:" + pid] = int(by_type.get("prop:" + pid, 0)) + 1
			elif m.markers.has(ch):
				markers_n += 1
				var mk: Dictionary = m.markers[ch]
				var t: String = str(mk["marker"])
				by_type[t] = int(by_type.get(t, 0)) + 1
				if not cells_of_type.has(t):
					cells_of_type[t] = []
				(cells_of_type[t] as Array).append({"cell": c, "m": mk})
				if t in Gen.SOLID_MARKERS:
					blockers[c] = true
			else:
				undeclared += 1
	_ok(T, "every_object_char_is_declared", undeclared == 0, str(undeclared))
	_ok(T, "exactly_one_default_spawn", spawn_cells.size() == 1, str(spawn_cells.size()))
	if spawn_cells.size() != 1:
		return
	var spawn: Vector2i = spawn_cells[0]
	# ---- exact feature counts from the spec
	var warps: Array = (cells_of_type.get("warp", []) as Array) + (cells_of_type.get("hulen", []) as Array)
	var hulen: Array = warps.filter(func(e: Dictionary) -> bool: return str((e["m"] as Dictionary).get("prop", "")) == "cave_ring" or ((e["m"] as Dictionary).has("floor") and not (e["m"] as Dictionary).has("home_rope")))
	var homes: Array = warps.filter(func(e: Dictionary) -> bool: return str((e["m"] as Dictionary).get("prop", "")) == "home_rope" or (e["m"] as Dictionary).has("home_rope"))
	var ups: Array = warps.filter(func(e: Dictionary) -> bool: return str((e["m"] as Dictionary).get("prop", "")) == "cave_ring_up")
	var want_next: String = "%s%d" % [prefix, floor_no + 1]
	var want_prev: String = str(hub.get("area", "moerkeskoven")) if floor_no == 1 else "%s%d" % [prefix, floor_no - 1]
	var hulen_type: String = str(cfg.get("hulen_marker", "warp"))
	var boss_flag_when: String = "flag:" + str((cfg.get("flags", {}) as Dictionary).get("boss_clear", "dg_boss_clear"))
	_ok(T, "hulen_count_matches_spec", hulen.size() == (1 if bool(spec["hulen"]) else 0), str(hulen.size()))
	if hulen.size() == 1:
		var hm: Dictionary = hulen[0]["m"]
		_ok(T, "hulen_targets_next_floor", str(hm["to"]) == want_next and (str(hm.get("spawn", "")) == "default" if hulen_type == "warp" else str(hm.get("floor", "")) == str(floor_no + 1)), str(hm))
		var sealed_tag: bool = (str(hm.get("when", "")) == boss_flag_when) if hulen_type == "warp" else (str(hm.get("sealed_by", "")) == str(spec["boss_kind"]) and bool(spec["boss"]))
		var unsealed_ok: bool = (not hm.has("when")) if hulen_type == "warp" else (not hm.has("sealed_by"))
		_ok(T, "hulen_sealed_iff_boss_floor", sealed_tag if bool(spec["boss"]) else unsealed_ok, str(hm))
	_ok(T, "home_rope_only_on_the_last_floor", homes.size() == (0 if bool(spec["hulen"]) else 1) and (homes.is_empty() or str((homes[0]["m"] as Dictionary)["to"]) == str(hub.get("area", "moerkeskoven"))), str(homes.size()))
	_ok(T, "up_warp_exactly_one_to_previous", ups.size() == 1 and str((ups[0]["m"] as Dictionary)["to"]) == want_prev, str(ups.size()))
	var from_down: Array = (cells_of_type.get("spawn", []) as Array).filter(func(e: Dictionary) -> bool: return str((e["m"] as Dictionary).get("name", "")) == "from_down")
	var rune_spawn: Array = (cells_of_type.get("spawn", []) as Array).filter(func(e: Dictionary) -> bool: return str((e["m"] as Dictionary).get("name", "")) == "rune")
	_ok(T, "spawn_from_down_iff_hulen", from_down.size() == (1 if bool(spec["hulen"]) else 0), str(from_down.size()))
	var rune_ok: bool = rune_spawn.size() == (1 if bool(spec["stone"]) else 0)
	if rune_ok and bool(spec["stone"]):
		var rcell: Vector2i = (cells_of_type.get("runestone", []) as Array)[0]["cell"]
		var d6: Vector2i = (rune_spawn[0]["cell"] as Vector2i) - rcell
		rune_ok = absi(d6.x) + absi(d6.y) == 1
	_ok(T, "spawn_rune_beside_the_runestone_iff_stone", rune_ok)
	_ok(T, "runestone_count_matches_spec", int(by_type.get("runestone", 0)) == (1 if bool(spec["stone"]) else 0))
	var chest_roles: Dictionary = {}
	var chests: Array = cells_of_type.get("chest", []) as Array
	for e in chests:
		var role: String = str((e["m"] as Dictionary).get("role", ""))
		chest_roles[role] = int(chest_roles.get(role, 0)) + 1
	var nook_main: bool = bool(spec["nook_main"])
	_ok(T, "chest_roles_match_spec", int(chest_roles.get("main", 0)) == (0 if nook_main else 1) and int(chest_roles.get("nook", 0)) == (1 if nook_main else 0)
		and int(chest_roles.get("lake", 0)) == (1 if str(spec["lake"]) != "" else 0) and int(chest_roles.get("boss", 0)) == (1 if bool(spec["boss"]) else 0) and chests.size() == int(chest_roles.get("main", 0)) + int(chest_roles.get("nook", 0)) + int(chest_roles.get("lake", 0)) + int(chest_roles.get("boss", 0)), str(chest_roles))
	var tiers_ok: bool = true
	for e in chests:
		var mk2: Dictionary = e["m"]
		var role2: String = str(mk2.get("role", ""))
		var want_tier: String = str(spec["chest_tier"]) if role2 in ["main", "nook"] else (str(spec["lake"]) if role2 == "lake" else "konge")
		if str(mk2.get("tier", "")) != want_tier:
			tiers_ok = false
		if (role2 == "lake") != mk2.has("lock"):
			tiers_ok = false
		if (role2 == "boss") != mk2.has("when"):
			tiers_ok = false
		if (role2 == "nook") != mk2.has("hidden"):
			tiers_ok = false
	_ok(T, "chest_tier_lock_and_seal_follow_role", tiers_ok)
	var spot_ids: Array = []
	for e in (cells_of_type.get("unique_spot", []) as Array):
		spot_ids.append(str((e["m"] as Dictionary)["id"]))
	spot_ids.sort()
	var want_spots: Array = (spec["spots"] as Array).duplicate()
	want_spots.sort()
	_ok(T, "unique_spots_equal_spec", spot_ids == want_spots, "%s vs %s" % [str(spot_ids), str(want_spots)])
	# enemies
	var enemies: Array = cells_of_type.get("enemy", []) as Array
	var n_boss: int = 0
	var n_ord: int = 0
	var n_amb: int = 0
	var n_crit: int = 0
	for e in enemies:
		var em: Dictionary = e["m"]
		if em.has("boss"):
			n_boss += 1
		elif em.has("critter"):
			n_crit += 1
		elif em.has("ambush"):
			n_amb += 1
		else:
			n_ord += 1
	_ok(T, "boss_count_matches_spec", n_boss == (1 if bool(spec["boss"]) else 0), str(n_boss))
	for e in enemies:
		if (e["m"] as Dictionary).has("boss"):
			_ok(T, "boss_kind_and_adds_follow_the_floor_table", str((e["m"] as Dictionary)["kind"]) == str(spec["boss_kind"]) and int((e["m"] as Dictionary)["adds"]) == int(spec["boss_adds"]), str(e["m"]))
	_ok(T, "enemies_at_least_80_percent_of_budget", (n_ord + n_amb) * 100 >= int(spec["enemies"]) * 80, "%d of %d" % [n_ord + n_amb, int(spec["enemies"])])
	T["stat_enemy_exact"] = int(T.get("stat_enemy_exact", 0)) + (1 if (n_ord + n_amb) == int(spec["enemies"]) else 0)
	T["stat_floors"] = int(T.get("stat_floors", 0)) + 1
	_ok(T, "ambush_and_critters_do_not_exceed_spec", n_amb <= int(spec["ambush"]) and n_crit <= int(spec["critters"]), "%d/%d %d/%d" % [n_amb, int(spec["ambush"]), n_crit, int(spec["critters"])])
	# nodes: no kind above its count
	var node_cnt: Dictionary = {}
	for e in (cells_of_type.get("node", []) as Array):
		var k: String = str((e["m"] as Dictionary)["kind"])
		node_cnt[k] = int(node_cnt.get(k, 0)) + 1
	var nodes_ok: bool = true
	var node_allow: Dictionary = (spec["nodes"] as Dictionary).duplicate()
	for an in (spec["anchors"] as Array):
		if str((an as Dictionary).get("marker", "")) == "node":
			for part in str(an["params"]).split(" ", false):
				if part.begins_with("kind="):
					node_allow[part.substr(5)] = int(node_allow.get(part.substr(5), 0)) + int(an.get("count", 1))
	for k in node_cnt:
		if int(node_cnt[k]) > int(node_allow.get(k, 0)):
			nodes_ok = false
	_ok(T, "node_kinds_within_spec", nodes_ok, str(node_cnt))
	var hard_ok: bool = true
	for hk in (spec["hard_nodes"] as Array):
		if int(node_cnt.get(str(hk), 0)) != int((spec["nodes"] as Dictionary).get(str(hk), 0)):
			hard_ok = false
	_ok(T, "required_node_kinds_are_exact_(moonstone_supply)", hard_ok, str(node_cnt))
	var expected_keepers := 0
	for anchor in spec["anchors"]:
		if str(anchor.get("marker", "")) == "hulen_keeper": expected_keepers += int(anchor.get("count", 1))
	var keepers: Array = cells_of_type.get("hulen_keeper", [])
	_ok(T, "required_story_witnesses_present", keepers.size() == expected_keepers and keepers.all(func(entry): return str(entry.m.get("npc", "")) == "mapseller_natteblik"), str(keepers))
	# lights
	var lights: Array = cells_of_type.get("light", []) as Array
	_ok(T, "lights_within_budget", lights.size() <= int(spec["lights_max"]), str(lights.size()))
	var worst: int = 0
	for e in lights:
		var cnt: int = 0
		for e2 in lights:
			var d: Vector2i = (e["cell"] as Vector2i) - (e2["cell"] as Vector2i)
			if 3 * d.x * d.x + d.y * d.y <= 3 * 5 * 5 + 5 * 5:
				cnt += 1
		worst = maxi(worst, cnt)
	_ok(T, "light_overlap_at_most_6_within_5_cells", worst <= 6, str(worst))
	# ---- geometry: borders, share, reachability
	var walkable_total: int = 0
	var play_cells: int = int(spec["w"]) * int(spec["h"])
	var border_ok: bool = true
	var max_x: int = pad_x + int(spec["w"])
	var max_y: int = pad_n + int(spec["h"])
	for y in h:
		for x in w:
			if WALK.contains(m.ground[y][x]):
				walkable_total += 1
				if x < pad_x + 3 or y < pad_n + 3 or x >= max_x - 3 or y >= max_y - 3:
					border_ok = false
	_ok(T, "forest_border_of_3_cells_is_not_walkable", border_ok)
	_ok(T, "walkable_share_within_limits", walkable_total * 100 >= play_cells * int(spec["min_walk_pct"]) and walkable_total * 100 <= play_cells * 100, "%d of %d" % [walkable_total, play_cells])
	T["stat_walk_pct_sum"] = int(T.get("stat_walk_pct_sum", 0)) + walkable_total * 1000 / play_cells
	# flood fill from the spawn (4-neighbourhood), blockers block
	var seen: Dictionary = {spawn: 0}
	var queue: Array = [spawn]
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cur + o
			if seen.has(nb) or nb.x < 0 or nb.y < 0 or nb.x >= w or nb.y >= h:
				continue
			if not WALK.contains(m.ground[nb.y][nb.x]) or blockers.has(nb):
				continue
			seen[nb] = int(seen[cur]) + 1
			queue.append(nb)
	var unreach: int = 0
	var unreach_first: Vector2i = Vector2i(-1, -1)
	for y in h:
		for x in w:
			if WALK.contains(m.ground[y][x]) and not blockers.has(Vector2i(x, y)) and not seen.has(Vector2i(x, y)):
				unreach += 1
				if unreach_first.x < 0:
					unreach_first = Vector2i(x, y)
	var snap: String = ""
	if unreach > 0:
		for yy in range(unreach_first.y - 4, unreach_first.y + 5):
			var line: String = ""
			for xx in range(unreach_first.x - 8, unreach_first.x + 9):
				var gc: String = m.ground_at(Vector2i(xx, yy))
				var oc: String = m.object_at(Vector2i(xx, yy))
				var tag: String = gc
				if oc != ".":
					if m.markers.has(oc):
						tag = str(m.markers[oc]["marker"]).substr(0, 1).to_upper()
					elif m.props.has(oc):
						tag = "p" if _solid_prop(str(m.props[oc]["prop"])) < 0 else "S"
					else:
						tag = oc
				if blockers.has(Vector2i(xx, yy)):
					tag = tag.to_lower() + "#"
				line += tag + " "
			snap += "\n" + line
	_ok(T, "no_unreachable_floor_islands", unreach == 0, "%d first at %s%s" % [unreach, str(unreach_first), snap])
	var all_reach: bool = true
	var bad_cell: String = ""
	for t2 in cells_of_type:
		if t2 == "light":
			continue
		for e in (cells_of_type[t2] as Array):
			var c2: Vector2i = e["cell"]
			var r: bool = seen.has(c2)
			if not r:
				for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if seen.has(c2 + o):
						r = true
			if not r:
				all_reach = false
				bad_cell = "%s at %s" % [t2, str(c2)]
	_ok(T, "every_marker_reachable_from_spawn", all_reach, bad_cell)
	if hulen.size() == 1:
		var hc: Vector2i = hulen[0]["cell"]
		var dd: int = absi(hc.x - spawn.x) + absi(hc.y - spawn.y)
		_ok(T, "hulen_far_from_spawn", dd >= int(spec["w"]) * 2 / 5, "manhattan %d" % dd)
		T["stat_route_sum"] = int(T.get("stat_route_sum", 0)) + int(seen.get(hc, 0))
		T["stat_route_n"] = int(T.get("stat_route_n", 0)) + 1
	# nook features are dead ends: at most 13 walkable cells in the 5 x 5 window round a unique spot / nook chest (the diamond pocket; its tip is the end of the spur)
	var hidden_ok: bool = true
	for t5 in ["unique_spot", "chest"]:
		for e in (cells_of_type.get(t5, []) as Array):
			if t5 == "chest" and str((e["m"] as Dictionary).get("role", "")) != "nook":
				continue
			var cc5: Vector2i = e["cell"]
			var wcount5: int = 0
			for yy5 in range(cc5.y - 2, cc5.y + 3):
				for xx5 in range(cc5.x - 2, cc5.x + 3):
					if WALK.contains(m.ground_at(Vector2i(xx5, yy5))):
						wcount5 += 1
			if wcount5 > 13:
				hidden_ok = false
	_ok(T, "nook_features_sit_in_hidden_dead_ends", hidden_ok)
	# enemies and chests keep away from the spawn
	var near_enemy: bool = false
	var near_chest: bool = false
	for e in enemies:
		var d3: Vector2i = (e["cell"] as Vector2i) - spawn
		var lim3: int = 100 if ((e["m"] as Dictionary).has("ambush") or (e["m"] as Dictionary).has("critter")) else 14 * 14
		if 3 * d3.x * d3.x + d3.y * d3.y < lim3:
			near_enemy = true
	for e in chests:
		var d4: Vector2i = (e["cell"] as Vector2i) - spawn
		if 3 * d4.x * d4.x + d4.y * d4.y < 120 and str((e["m"] as Dictionary).get("role", "")) != "boss":
			near_chest = true
	_ok(T, "no_enemy_near_spawn_(14_ordinary_8_ambush_or_critter)", not near_enemy)
	_ok(T, "no_chest_next_to_spawn", not near_chest)
	# solid features stay off the lit path (floors whose path char differs from the patch char)
	var terr: Dictionary = spec["terrain"] as Dictionary
	if str(terr["path"]) != str(terr["patch"]):
		var on_path: bool = false
		for t3 in ["chest", "node", "runestone", "unique_spot"]:
			for e in (cells_of_type.get(t3, []) as Array):
				var c3: Vector2i = e["cell"]
				if m.ground[c3.y][c3.x] == str(terr["path"]) and str((e["m"] as Dictionary).get("role", "")) not in ["nook"]:
					on_path = true
		_ok(T, "solid_features_stay_off_the_lit_path", not on_path)
	# lake chest next to a pond cell
	for e in chests:
		if (e["m"] as Dictionary).has("lock"):
			var c4: Vector2i = e["cell"]
			var by_pond: bool = false
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if m.ground_at(c4 + o) == "~":
					by_pond = true
			_ok(T, "lake_chest_stands_on_a_pond_shore", by_pond)
	# nook features sit in a dead end: the cell has at most 2 walkable 4-neighbours among... (pocket) - checked through spawn distance instead
	# boss arena room
	if bool(spec["boss"]):
		for e in enemies:
			if (e["m"] as Dictionary).has("boss"):
				var bc: Vector2i = e["cell"]
				var room: int = 0
				for y in range(maxi(0, bc.y - 12), mini(h, bc.y + 13)):
					for x in range(maxi(0, bc.x - 12), mini(w, bc.x + 13)):
						var dd2: Vector2i = Vector2i(x, y) - bc
						if 3 * dd2.x * dd2.x + dd2.y * dd2.y <= 12 * 12 and WALK.contains(m.ground[y][x]):
							room += 1
				_ok(T, "boss_arena_has_room", room >= 150, str(room))
	# tutorial ambush on floors 1-2
	if floor_no <= 2 and int(spec["ambush"]) > 0:
		var ok_t: bool = false
		for e in enemies:
			if (e["m"] as Dictionary).has("ambush"):
				var d5: Vector2i = (e["cell"] as Vector2i) - spawn
				var q: int = 3 * d5.x * d5.x + d5.y * d5.y
				if q >= 150 and q <= 420:
					ok_t = true
		_ok(T, "tutorial_ambush_6_to_11_cells_from_spawn", ok_t)
	# ---- canopy: no feature under a crown, rim crowns hug the void, budgets
	var cover_bad: int = 0
	var rim_n: int = 0
	var inner_n: int = 0
	var cls_n: Array = [0, 0, 0]
	var prot_cells: Array = []
	for t4 in cells_of_type:
		for e in (cells_of_type[t4] as Array):
			prot_cells.append(e["cell"])
	prot_cells.append(spawn)
	var walk_ov_bad: int = 0
	var cover_msg: String = ""
	for cr in crowns:
		var cc: Vector2i = cr["cell"]
		var cls2: int = int(cr["cls"])
		cls_n[cls2] += 1
		if bool(cr["walk"]):
			inner_n += 1
		else:
			rim_n += 1
		for pc in prot_cells:
			if Gen.crown_covers(cls2, cc.x, cc.y, pc.x, pc.y):
				cover_bad += 1
				if cover_msg == "":
					cover_msg = "crown %s cls %d walk %s at %s covers %s (spawn %s)" % [str(cr["pid"]), cls2, str(cr["walk"]), str(cc), str(pc), str(spawn)]
		if not bool(cr["walk"]):
			var ov: int = 0
			for r3 in Gen.crown_rows(cls2):
				var yy: int = cc.y + r3.x
				if yy < 0 or yy >= h:
					continue
				for xx in range(maxi(cc.x + r3.y, 0), mini(cc.x + r3.z, w - 1) + 1):
					if WALK.contains(m.ground[yy][xx]):
						ov += 1
			if ov > 4:
				walk_ov_bad += 1
	_ok(T, "no_feature_or_spawn_under_a_crown_disc", cover_bad == 0, cover_msg)
	_ok(T, "rim_crown_walk_overlap_at_most_4_cells", walk_ov_bad == 0, str(walk_ov_bad))
	_ok(T, "inner_crowns_match_spec_or_fewer", inner_n <= int(spec["inner_crowns"]), "%d vs %d" % [inner_n, int(spec["inner_crowns"])])
	_ok(T, "rim_crowns_present", rim_n >= 20, str(rim_n))
	_ok(T, "props_total_within_budget", props_n <= int((cfg.get("limits", {}) as Dictionary).get("props_max", 800)), str(props_n))
	T["stat_props_max"] = maxi(int(T.get("stat_props_max", 0)), props_n)
	T["stat_rim_sum"] = int(T.get("stat_rim_sum", 0)) + rim_n
	T["stat_rim_max"] = maxi(int(T.get("stat_rim_max", 0)), rim_n)
	# wall tile budget: the busiest 33 x 32 window (one screen at zoom 0.4) holds at most 400 wall cells
	var wcount := PackedInt32Array()
	wcount.resize((w + 1) * (h + 1))
	for y in h:
		var run: int = 0
		for x in w:
			run += 1 if m.ground[y][x] == "W" else 0
			wcount[(y + 1) * (w + 1) + x + 1] = wcount[y * (w + 1) + x + 1] + run
	# props in the busiest 33 x 32 window
	var pcount := PackedInt32Array()
	pcount.resize((w + 1) * (h + 1))
	for y in h:
		var runp: int = 0
		for x in w:
			runp += 1 if (m.objects[y][x] != "." and m.props.has(m.objects[y][x])) else 0
			pcount[(y + 1) * (w + 1) + x + 1] = pcount[y * (w + 1) + x + 1] + runp
	var worst_p: int = 0
	for y in range(0, maxi(1, h - 32 + 1), 4):
		for x in range(0, maxi(1, w - 33 + 1), 4):
			var x3: int = mini(x + 33, w)
			var y3: int = mini(y + 32, h)
			worst_p = maxi(worst_p, pcount[y3 * (w + 1) + x3] - pcount[y * (w + 1) + x3] - pcount[y3 * (w + 1) + x] + pcount[y * (w + 1) + x])
	_ok(T, "props_in_view_at_most_400", worst_p <= int((cfg.get("limits", {}) as Dictionary).get("props_view_max", 400)), str(worst_p))
	T["stat_props_view_max"] = maxi(int(T.get("stat_props_view_max", 0)), worst_p)
	var worst_w: int = 0
	for y in range(0, maxi(1, h - 32 + 1), 4):
		for x in range(0, maxi(1, w - 33 + 1), 4):
			var x2: int = mini(x + 33, w)
			var y2: int = mini(y + 32, h)
			var s: int = wcount[y2 * (w + 1) + x2] - wcount[y * (w + 1) + x2] - wcount[y2 * (w + 1) + x] + wcount[y * (w + 1) + x]
			worst_w = maxi(worst_w, s)
	_ok(T, "visible_wall_tiles_at_most_400_per_screen", worst_w <= 400, str(worst_w))
	T["stat_wall_window_max"] = maxi(int(T.get("stat_wall_window_max", 0)), worst_w)
