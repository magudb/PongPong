extends RefCounted
## Section content_features (package F1, wave 3): the feature content as the GAME loaded it.
##
## What it proves (named checks, every one reads the real LuaRuntime / LocalizationManager / EconomyManager / QuestManager, nothing is mocked except the missing wave-4 managers):
##   ids_load                                   258 ids (130 furniture + 96 clothing + 32 materials) load via LuaRuntime.get_item_def and equal the ids the three Lua files declare
##   lint_clean                                 0 lint findings in any file of this package
##   loc_keys_da_en                             every row of the 8 CSVs resolves in da AND en through LocalizationManager (no raw key comes back)
##   loc_check_no_missing_f1_key                tests/loc_check.gd (child process): no key that one of the 8 files owns is missing anywhere (the ids' ITEM_/_DESC/_HINT keys, shops, sets, tiers, builder lines ...)
##   art_spec_equals_lua                        furniture: template / layer / footprint / rarity == A1's shipped manifest (furniture.json); garments: art == the wardrobe art spec
##   catalogue_rules, sources_both_ways_30_unique_19_legendary, no_craft_sell_loop, hearts_reachable, finds_and_shops_both_ways
##                                              the Lua-level rules of tests/lib/features/content_validator.gd
##   starter_kit_valid, starter_kit_places      lua/data/starter_kit.lua: ids, normal pieces, the whole kit places in the room of tier 1 (data-level rules), the kit stays below hygge level 1
##   starter_kit_through_economy                the placed pieces go through EconomyManager.add_item -> the furniture store -> place_from_stock (a stand-in store until F3)
##   builder_dialogue_29_branches               the REAL lua/dialogue/fairy_builder.lua picks the right branch for 29 flag combinations; the two shopkeepers open their shops
##   dialogue_shop_buttons_open_real_shops      (review F1 r1) in all 31 dialogue states (29 builder flag combinations + furnisher + tailor) every open_shop choice names a shop that exists and is kept by the
##                                              speaker, and every shop_id literal of the three Lua files is a shop; negative controls: a typo, another keeper's shop, a state without a button
##   shop_open_weekdays_valid                   (review F1 r1) open_weekdays are weekday indices 0..6; only the flea market has any and they are exactly {5, 6}; negative controls {5, 7}, missing, other shop
##   map_markers_equal_loot_tables              (review F1 r1) data/features/map_markers.json == lua/data/loot_tables.lua per area (chests, creatures, unique spots, boss); negative controls: area id, count, spot, boss
##   rules_selftest_*                           (review F1 r1) tools/features/validate/rules_selftest.py: the helpers of validator rules N1 (scan not vacuous below the default _stage path), SH1, S10, MM1 are seen failing;
##                                              (review F1 r2) N1 on .map / .svg / .tscn / .tres, R21, Q5, C19 / C20, SH2, R7d, K10, K9, D6
##   hygge_accessor_is_hygge_score              (review F1 r2) Grant + AutoFurnish work against a manager that has ONLY the binding accessor FurnitureManager.hygge_score() (PLAN_FEATURES.md section 3
##                                              task 4, RF16), report a manager that only has the prototype's hygge_total(), and no helper of tests/lib/features calls hygge_total()
##   spot_requirements_valid, quest_references_valid, furniture_max_stack_rule, shop_stock_numbers_valid, wardrobe_equip_slot_z_distinct, voice_keys_follow_speaker_and_line, no_text_literals_in_f1_lua,
##   creature_name_keys_defined_or_pending      (review F1 r2) the references and numbers that no rule looked at, each on the real data AND on deliberately broken copies
##   rename_town_*                              (review F1 r2) tools/features/test_rename_town.py: an empty / blank --old is refused, .map / .svg / .tscn / .tres are rewritten
##   pending_offers_accepted_by_dialogue        the reference dialogues (data/features/pending) offer the four gating quests and accepting through the choice activates them (rule S13 inside the harness)
##   grant_requirements_tiers_2_to_10           Grant.requirements(n) gives every requirement of every tier through the public APIs only (needs the pending dialogues for the gate quests)
##   auto_furnish_reaches_target, fresh_resets_everything, room_model_rules   the helpers of tests/lib/features
##   add_autoload_*                             tools/features/add_autoload.py: second run no-op, parallel runs do not corrupt the file (python self-test), and check_project.gd accepts its result
##   validator_gate_files_exist, stage_manifest_covers_the_package   the offline validator + mutation test + self-tests exist and the stage manifest names every file of the package
##                                              (this section does NOT run the offline validator: run_validate.sh --stage f1 and mutation_test.py are the separate gates below)
## The offline staged validator (tools/features/validate/run_validate.sh --stage f1, 102 rules) and its mutation test (48 mutants) are separate gates (docs/features/STAGES.md).
const SECTION := "content_features"
const TIMEOUT_S := 300.0

const F1_LUA := ["lua/items/furniture.lua", "lua/items/clothing.lua", "lua/items/building_materials.lua", "lua/recipes/furniture.lua", "lua/recipes/materials.lua", "lua/shops/home_shops.lua",
	"lua/data/home_tiers.lua", "lua/data/loot_tables.lua", "lua/data/sets.lua", "lua/data/wardrobe_rules.lua", "lua/data/starter_kit.lua",
	"lua/quests/bogtraeet.lua", "lua/quests/moonstone_crown.lua", "lua/quests/snurresvampen.lua", "lua/quests/slotsdroemmen.lua",
	"lua/dialogue/fairy_builder.lua", "lua/dialogue/fairy_furnisher.lua", "lua/dialogue/fairy_tailor.lua"]
const F1_CSVS := ["furniture", "wardrobe", "materials", "home", "finds", "features_ui", "features_quests", "dialogue_builder"]
const PENDING_DIALOGUES := ["guard_oak", "fairy_wizard", "fairy_king"]
const FEATURE_CATEGORIES := ["furniture", "clothing", "building_material", "gem", "blueprint"]

var _lr: Node
var _lm: Node


func run(t) -> void:
	_lr = t.autoload("LuaRuntime")
	_lm = t.autoload("LocalizationManager")
	if _lr == null or _lm == null:
		return
	Svc.clear_overrides()
	_items_and_lint(t)
	_localization(t)
	_art_specs(t)
	_validator_rules(t)
	_review_fix_rules(t)
	_review2_rules(t)
	_starter_kit(t)
	_room_model(t)
	_builder_dialogue(t)
	_pending_offers_and_grant(t)
	_helpers(t)
	_hygge_accessor(t)
	_autoload_tool(t)
	_rename_tool(t)
	_rules_selftest(t)
	_validator_gate(t)
	Svc.clear_overrides()
	_lr.reload_scripts()


# ---------------------------------------------------------------------------------------------------------- items + lint

## the ids this package declares that the runtime really loaded (other packages add items too: they are not counted)
func _feature_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in ContentValidator.declared_ids():
		if not _lr.get_item_def(id).is_empty() and str(_lr.get_item_def(id).get("category", "")) in FEATURE_CATEGORIES:
			ids.append(id)
	return ids


func _items_and_lint(t) -> void:
	var ids := _feature_ids()
	var declared := ContentValidator.declared_ids()
	var counts := {"furniture": 0, "clothing": 0, "materials": 0}
	for id in ids:
		var cat := str(_lr.get_item_def(id).get("category", ""))
		counts["furniture" if cat == "furniture" else ("clothing" if cat == "clothing" else "materials")] += 1
	t.check("ids_load", ids.size() == 258 and ids == declared and counts == {"furniture": 130, "clothing": 96, "materials": 32}, "%d ids loaded, %d declared, %s" % [ids.size(), declared.size(), str(counts)])
	var bad: Array[String] = []
	var mine: Array[String] = []
	for f in F1_LUA:
		mine.append("res://" + f)
	for finding in _lr.lint_report:
		if str(finding.get("path", "")) in mine:
			bad.append("%s:%s %s" % [finding.get("path", ""), finding.get("line", ""), finding.get("message", "")])
	t.check("lint_clean", bad.is_empty(), "%d finding(s) in the %d files of this package: %s" % [bad.size(), F1_LUA.size(), str(bad.slice(0, 3))])
	t.expect(_lr.lint_report is Array, "LuaRuntime keeps a lint report")
	for f in F1_LUA:
		t.expect(FileAccess.file_exists("res://" + f), "%s exists" % f)


# ---------------------------------------------------------------------------------------------------------- localization

func _csv_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for n in F1_CSVS:
		var fa := FileAccess.open("res://localization/%s.csv" % n, FileAccess.READ)
		if fa == null:
			continue
		fa.get_csv_line()
		while not fa.eof_reached():
			var line := fa.get_csv_line()
			if line.size() >= 3 and line[0] != "":
				rows.append({"file": n, "key": line[0], "da": line[1], "en": line[2]})
	return rows


func _localization(t) -> void:
	var rows := _csv_rows()
	var raw: Array[String] = []
	for r in rows:
		var k := str(r["key"])
		var da := str(_lm.text_in(k, "da"))
		var en := str(_lm.text_in(k, "en"))
		if da == "" or en == "" or da == k or en == k or da != _lm.unescape_text(str(r["da"])) or en != _lm.unescape_text(str(r["en"])):
			raw.append(k)
	t.check("loc_keys_da_en", rows.size() == 906 and raw.is_empty(), "%d rows of 8 files, %d unresolved or different from the CSV: %s" % [rows.size(), raw.size(), str(raw.slice(0, 5))])
	# every item has its three keys in both languages through the runtime lookup (what a Label with the key shows)
	var missing: Array[String] = []
	for id in _feature_ids():
		for suffix in ["", "_DESC"]:
			var k := "ITEM_%s%s" % [id.to_upper(), suffix]
			if not (_lm.has_key(k) and str(_lm.t(k)) != k):
				missing.append(k)
	t.expect(missing.is_empty(), "name and description of all 258 ids translate (missing: %s)" % str(missing.slice(0, 5)))
	var en_probe := _locale_probe(t)
	t.expect(en_probe, "the Danish and the English text of an item differ after set_locale (no raw key in either language)")
	# loc_check as the project's own tool: no key that one of the 8 files owns is reported missing
	var res: Dictionary = t.run_godot_script("res://tests/loc_check.gd")
	var owners: Dictionary = _lm.load_owners("res://")
	var f1_files: Array[String] = []
	for n in F1_CSVS:
		f1_files.append(n + ".csv")
	var f1_missing: Array[String] = []
	var miss_total := 0
	for line in res.get("lines", []):
		var l := str(line)
		if l.begins_with("MISS "):
			miss_total += 1
			var key := l.split(" ")[2]
			if _lm.owner_of(key, owners) in f1_files:
				f1_missing.append(key)
	t.check("loc_check_no_missing_f1_key", int(res.get("code", -1)) == 0 and f1_missing.is_empty(), "loc_check exit %s, %d miss lines of other packages, F1 keys missing: %s" % [str(res.get("code", "?")), miss_total, str(f1_missing.slice(0, 5))])


func _locale_probe(t) -> bool:
	var before: String = TranslationServer.get_locale().substr(0, 2)
	_lm.set_locale("en", false)
	var en: String = _lm.t("ITEM_BED_PINE")
	_lm.set_locale("da", false)
	var da: String = _lm.t("ITEM_BED_PINE")
	_lm.set_locale(before if before in ["da", "en"] else "da", false)
	return en != da and en != "ITEM_BED_PINE" and da != "ITEM_BED_PINE"


# ---------------------------------------------------------------------------------------------------------- art specs

func _art_specs(t) -> void:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/iso_props/furniture/furniture.json"))
	var bad: Array[String] = []
	var checked := 0
	if typeof(manifest) == TYPE_DICTIONARY and (manifest as Dictionary).has("items"):
		var items: Dictionary = manifest["items"]
		for id in _feature_ids():
			var d: Dictionary = _lr.get_item_def(id)
			if str(d.get("category", "")) != "furniture":
				continue
			checked += 1
			if not items.has(id):
				bad.append("%s: no art entry" % id)
				continue
			var a: Dictionary = items[id]
			var fp := LuaData.arr(d.get("footprint", []))
			var afp: Array = a.get("footprint", [])
			if str(a.get("template", "")) != str(LuaData.dict(d.get("art", {})).get("template", "")) or str(a.get("layer", "")) != str(d.get("placement", "")) \
					or afp.size() != 2 or int(afp[0]) != LuaData.int_of(fp[0]) or int(afp[1]) != LuaData.int_of(fp[1]) or str(a.get("rarity", "")) != str(d.get("rarity", "")):
				bad.append("%s: art %s/%s/%s vs lua %s/%s/%s" % [id, a.get("template", "?"), a.get("layer", "?"), str(afp), LuaData.dict(d.get("art", {})).get("template", "?"), d.get("placement", "?"), str(fp)])
	else:
		bad.append("assets/iso_props/furniture/furniture.json is missing or malformed (A1)")
	# garments: the wardrobe art spec (A2's tools/art/features/wardrobe/specs once it landed, else the pending copy in data/features)
	var spec_path := "res://tools/art/features/wardrobe/specs/wardrobe_art_spec.json"
	if not FileAccess.file_exists(spec_path):
		spec_path = "res://data/features/pending/art/wardrobe_art_spec.json"
	var spec: Variant = JSON.parse_string(FileAccess.get_file_as_string(spec_path))
	var garments := 0
	if typeof(spec) == TYPE_DICTIONARY:
		var by_id := {}
		for e in (spec as Dictionary).get("items", []):
			by_id[str((e as Dictionary).get("id", ""))] = e
		for id in _feature_ids():
			var d: Dictionary = _lr.get_item_def(id)
			if str(d.get("category", "")) != "clothing":
				continue
			garments += 1
			var art := LuaData.dict(d.get("art", {}))
			var e: Dictionary = by_id.get(id, {})
			if e.is_empty() or str(e.get("layer", "")) != str(art.get("layer", "")) or str(e.get("rarity", "")) != str(d.get("rarity", "")) or str(e.get("status", "")) != str(art.get("status", "")):
				bad.append("%s: wardrobe art spec differs" % id)
			else:
				var pal := LuaData.strings(art.get("palette", []))
				var spal: Array = e.get("palette", [])
				for i in pal.size():
					if i >= spal.size() or str(spal[i]).to_upper() != pal[i].to_upper():
						bad.append("%s: palette differs" % id)
						break
	else:
		bad.append("%s is missing" % spec_path)
	t.check("art_spec_equals_lua", bad.is_empty() and checked == 130 and garments == 96, "%d furniture + %d garments compared; %s" % [checked, garments, str(bad.slice(0, 4))])


# ---------------------------------------------------------------------------------------------------------- the Lua-level rules

func _validator_rules(t) -> void:
	var v := ContentValidator.new()
	v.run()
	var by_group := {"sources": [], "loop": [], "hearts": [], "finds": [], "rest": []}
	for e in v.errors:
		var l := e.to_lower()
		if l.contains("keepsake") or l.contains("source") or l.contains("tier gift") or l.contains("spot ") or l.contains("boss"):
			by_group["sources"].append(e)
		elif l.contains("recipe") or l.contains("money loop") or l.contains("processing"):
			by_group["loop"].append(e)
		elif l.contains("hearts"):
			by_group["hearts"].append(e)
		elif l.contains("shop") or l.contains("loot pool") or l.contains("find zones"):
			by_group["finds"].append(e)
		else:
			by_group["rest"].append(e)
	t.check("catalogue_rules", v.errors.is_empty(), "%d error(s): %s" % [v.errors.size(), str(v.errors.slice(0, 4))])
	t.check("sources_both_ways_30_unique_19_legendary", int(v.stats.get("unique", 0)) == 30 and int(v.stats.get("legendary", 0)) == 19 and by_group["sources"].is_empty(), "%s unique / %s legendary, source errors %s" % [v.stats.get("unique", "?"), v.stats.get("legendary", "?"), str(by_group["sources"].slice(0, 3))])
	t.check("finds_and_shops_both_ways", by_group["finds"].is_empty() and int(v.stats.get("shops", 0)) == 4, "%s shops, errors %s" % [v.stats.get("shops", "?"), str(by_group["finds"].slice(0, 3))])
	t.check("no_craft_sell_loop", by_group["loop"].is_empty() and int(v.stats.get("build_recipes", 0)) == 95 and int(v.stats.get("recipe_loops", -1)) == 0, "%s build recipes, %s loops, errors %s" % [v.stats.get("build_recipes", "?"), v.stats.get("recipe_loops", "?"), str(by_group["loop"].slice(0, 3))])
	t.check("hearts_reachable", by_group["hearts"].is_empty() and int(v.stats.get("heart_asks", 0)) >= 10, "%s gates and gifts ask hearts, the most needs %s days of weekly chats; %s" % [v.stats.get("heart_asks", "?"), v.stats.get("weekly_chat_days_for_the_most_hearts", "?"), str(by_group["hearts"].slice(0, 3))])
	# negative control of the rules themselves: a copy of the data with one defect must be reported (the validator is not a rubber stamp)
	var d: Dictionary = _lr.get_item_def("bed_pine")
	var keep_sell: Variant = d.get("sell_price", 0)
	d["sell_price"] = 999999
	var v2 := ContentValidator.new()
	v2.run()
	d["sell_price"] = keep_sell
	t.expect(not v2.errors.is_empty() and str(v2.errors[0]).contains("bed_pine"), "negative control: a sell price above the buy price is reported (%s)" % str(v2.errors.slice(0, 1)))


# ---------------------------------------------------------------------------------------------------------- review F1 r1: shop days, map markers

func _review_fix_rules(t) -> void:
	var shops: Dictionary = LuaData.dict(_lr.get_shops())
	var sched := ContentValidator.shop_schedule_problems(shops)
	var flea := LuaData.arr(LuaData.dict(shops.get("flea_market", {})).get("open_weekdays", []))
	t.check("shop_open_weekdays_valid", sched.is_empty() and flea.size() == 2 and int(flea[0]) == 5 and int(flea[1]) == 6, "%d problem(s) %s; flea market days %s" % [sched.size(), str(sched.slice(0, 3)), str(flea)])
	var copy := shops.duplicate(true)
	(copy["flea_market"] as Dictionary)["open_weekdays"] = [5, 7]
	t.expect(not ContentValidator.shop_schedule_problems(copy).is_empty(), "negative control: open_weekdays {5, 7} (a weekday that does not exist) is reported")
	copy = shops.duplicate(true)
	(copy["flea_market"] as Dictionary).erase("open_weekdays")
	t.expect(not ContentValidator.shop_schedule_problems(copy).is_empty(), "negative control: a flea market without opening days (open every day) is reported")
	copy = shops.duplicate(true)
	(copy["tailor_shop"] as Dictionary)["open_weekdays"] = [0, 1]
	t.expect(not ContentValidator.shop_schedule_problems(copy).is_empty(), "negative control: opening days on a shop that is open daily are reported")
	# the marker list the map authors build from
	var markers := ContentValidator.load_map_markers()
	var loot := LuaData.dict(_lr.get_config("loot", {}))
	var mm := ContentValidator.map_marker_problems(markers, loot)
	t.check("map_markers_equal_loot_tables", mm.is_empty() and LuaData.dict(markers.get("areas", {})).size() == 6, "%d area(s), %d problem(s): %s" % [LuaData.dict(markers.get("areas", {})).size(), mm.size(), str(mm.slice(0, 3))])
	for op in ["rename_area", "chest_count", "creature_count", "missing_spot", "no_boss"]:
		t.expect(not _marker_problems_after(markers, loot, op).is_empty(), "negative control: the map marker defect '%s' is reported" % op)


## the marker list with ONE defect applied (a deep copy: the real file content is never touched)
func _marker_problems_after(markers: Dictionary, loot: Dictionary, op: String) -> Array[String]:
	var m := markers.duplicate(true)
	var areas := m["areas"] as Dictionary
	match op:
		"rename_area":
			areas["hyggebyenx"] = areas["hyggebyen"]
			areas.erase("hyggebyen")
		"chest_count":
			((areas["dybe_bregner"] as Dictionary)["containers"] as Dictionary)["dig"] = 4
		"creature_count":
			((areas["skovkant"] as Dictionary)["creatures"] as Dictionary)["bat"] = 2
		"missing_spot":
			((areas["dybe_bregner"] as Dictionary)["unique_spots"] as Array).pop_back()
		"no_boss":
			(areas["dybe_bregner"] as Dictionary).erase("boss")
	return ContentValidator.map_marker_problems(m, loot)


# ---------------------------------------------------------------------------------------------------------- starter kit

func _starter_kit(t) -> void:
	var kit := LuaData.dict(_lr.get_config("starter_kit", {}))
	var wardrobe := LuaData.dict(kit.get("wardrobe", {}))
	var furniture := LuaData.dict(kit.get("furniture", {}))
	var worn := LuaData.strings(wardrobe.get("worn", []))
	var owned := LuaData.strings(wardrobe.get("owned", []))
	var placed := LuaData.strings(furniture.get("placed", []))
	var stock := LuaData.int_map(furniture.get("stock", {}))
	var ok := worn == ["shirt_linen_cream", "pants_trousers_brown", "shoes_boots_brown"] and owned == ["dress_sun_cream"] and placed == ["bed_birch_single", "chest_pine"] \
		and stock == {"table_round_pine": 1, "chair_pine": 2, "rug_runner_natural": 1, "floor_lamp_iron": 1}
	var all_exist := true
	var kit_ids: Array = []
	kit_ids.append_array(worn)
	kit_ids.append_array(owned)
	kit_ids.append_array(placed)
	kit_ids.append_array(stock.keys())
	for id in kit_ids:
		var d: Dictionary = _lr.get_item_def(str(id))
		all_exist = all_exist and not d.is_empty() and str(d.get("rarity", "")) == "normal"
	t.check("starter_kit_valid", ok and all_exist, "the text of addendum 2.7: worn %s owned %s placed %s stock %s" % [str(worn), str(owned), str(placed), str(stock)])
	# the kit places in the room of tier 1 (data-level rules) and stays below the first hygge level
	var room := FeatureRoom.load_tier(1)
	var count := 0
	var all_ids: Array[String] = []
	all_ids.append_array(placed)
	for id in stock:
		for _n in int(stock[id]):
			all_ids.append(str(id))
	for id in all_ids:
		var spot := room.find_spot(id) if room != null else {}
		if spot.is_empty():
			break
		room.place(id, spot["cell"], int(spot["rot"]))
		count += 1
	var first_level: int = LuaData.int_of(LuaData.dict(LuaData.arr(Svc.lua_config("home.hygge_levels", []))[1]).get("min_decor", 0))
	t.check("starter_kit_places", room != null and count == all_ids.size() and count == 7 and room.decor_total() < first_level, "%d of %d pieces placed in the room of tier 1 (%d slots), decor %s below %d" % [count, all_ids.size(), room.max_furniture if room != null else -1, str(room.decor_total() if room != null else -1), first_level])
	# through the economy: add_item routes a furniture piece into the furniture store (a stand-in until F3), place_from_stock puts it into the room
	Fresh.new_game(t)
	var fake := FakeFurnitureManager.new(1)
	Svc.override("FurnitureManager", fake)
	var eco: Node = t.autoload("EconomyManager")
	var placed_ok := 0
	var routed := true
	for id in placed:
		routed = routed and bool(eco.add_item(StringName(id), 1, true)) and fake.count_stock(id) == 1 and int(eco.count_item(StringName(id))) == 1
		var spot := fake.room.find_spot(id)
		if not spot.is_empty() and bool(fake.place_from_stock(id, spot["cell"], int(spot["rot"]))["ok"]):
			placed_ok += 1
	for id in stock:
		routed = routed and bool(eco.add_item(StringName(id), int(stock[id]), true)) and fake.count_stock(id) == int(stock[id])
	t.check("starter_kit_through_economy", routed and placed_ok == 2 and fake.hygge_score() > 0 and fake.hygge_score() < first_level and int(eco.count_item(&"chest_pine")) == 1, "routed %s, placed %d of 2, hygge %d (level 1 at %d)" % [str(routed), placed_ok, fake.hygge_score(), first_level])
	Svc.clear_overrides()
	fake.free()
	Fresh.new_game(t)


# ---------------------------------------------------------------------------------------------------------- the room model of the helpers

func _room_model(t) -> void:
	var room := FeatureRoom.load_tier(1)
	t.expect(room != null and room.cells.size() == 20 and room.max_furniture == 11 and room.door == Vector2i(2, 3) and room.spawn == Vector2i(2, 2), "tier 1 room: 20 cells, 11 slots, door (2,3), spawn (2,2)")
	t.expect(bool(room.place("bed_birch_single", Vector2i(0, 0), 0)["ok"]), "a bed (1x2) fits in the back-left corner")
	t.expect(str(room.can_place("chest_pine", Vector2i(0, 1), 0)["reason"]) == "overlap", "overlap is refused (the bed covers (0,0) and (0,1))")
	t.expect(str(room.can_place("chest_pine", Vector2i(9, 9), 0)["reason"]) == "outside", "a cell outside the room is refused")
	t.expect(str(room.can_place("chest_pine", room.door, 0)["reason"]) == "door", "the door cell stays free")
	t.expect(str(room.can_place("chest_pine", room.spawn, 0)["reason"]) == "door", "the cell before the door stays free")
	t.expect(FeatureRoom.layer_of("painting_small_pine") == "wall" and str(room.can_place("painting_small_pine", Vector2i(3, 2), 0)["reason"]) == "not_on_wall", "a wall piece in the middle of the floor is refused")
	t.expect(bool(room.can_place("painting_small_pine", Vector2i(3, 0), 0)["ok"]), "the same wall piece on the back wall is accepted")
	t.expect(str(room.can_place("vase_clay", Vector2i(3, 1), 0)["reason"]) == "needs_table", "a tabletop piece needs a surface under it")
	t.expect(bool(room.place("table_round_pine", Vector2i(3, 1), 0)["ok"]) and bool(room.can_place("vase_clay", Vector2i(3, 1), 0)["ok"]), "...and is accepted on a table")
	t.expect(bool(room.place("rug_runner_natural", Vector2i(1, 2), 0)["ok"]) and str(room.can_place("rug_runner_natural", Vector2i(2, 2), 0)["reason"]) == "overlap", "rugs live on their own layer (one per cell)")
	# capacity is a hard limit
	var small := FeatureRoom.load_tier(1)
	small.max_furniture = 1
	small.place("chest_pine", Vector2i(0, 0), 0)
	t.expect(str(small.can_place("chair_pine", Vector2i(1, 0), 0)["reason"]) == "capacity", "the tier's furniture capacity is a hard limit")
	# the path rule: two chests beside the bed are fine, the third one would wall the bed in
	var tight := FeatureRoom.load_tier(1)
	tight.place("bed_birch_single", Vector2i(0, 0), 0)
	var c1 := bool(tight.place("chest_pine", Vector2i(1, 0), 0)["ok"])
	var c2 := bool(tight.place("chest_pine", Vector2i(1, 1), 0)["ok"])
	t.expect(c1 and c2 and str(tight.can_place("chest_pine", Vector2i(0, 2), 0)["reason"]) == "path", "no piece may wall in the free side of an interactive piece (path rule)")
	var spot := room.find_spot("chair_pine")
	t.expect(spot.size() == 2 and spot.has("cell") and spot.has("rot"), "find_spot gives {cell, rot}")


# ---------------------------------------------------------------------------------------------------------- the real fairy_builder

func _flags(gm: Node, flags: Dictionary) -> void:
	gm.world_flags.clear()
	for k in flags:
		gm.set_flag(StringName(k), flags[k])


func _lines_of(d: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for l in LuaData.arr(d.get("lines", [])):
		out.append(str(LuaData.dict(l).get("text_key", "")))
	return out


func _has_choice(d: Dictionary, action: String) -> bool:
	for c in LuaData.arr(d.get("choices", [])):
		if str(LuaData.dict(c).get("action", "")) == action:
			return true
	return false


## one flag state of a dialogue as ContentValidator.dialogue_shop_problems wants it
func _state_of(npc: String, label: String, d: Dictionary) -> Dictionary:
	var choices: Array = []
	for c in LuaData.arr(d.get("choices", [])):
		var cd := LuaData.dict(c)
		choices.append({"action": str(cd.get("action", "")), "shop_id": str(cd.get("shop_id", ""))})
	return {"npc": npc, "label": label, "choices": choices}


func _builder_dialogue(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var bad: Array[String] = []
	var states: Array = []
	var n := 0
	var expected_idle := func(tier: int) -> Array[String]:
		var e: Array[String] = ["DLG_BUILDER_T%02d_IDLE" % tier]
		if tier < 10:
			e.append("DLG_BUILDER_T%02d_OFFER" % tier)
		return e
	_flags(gm, {})
	var d: Dictionary = _lr.get_dialogue("fairy_builder", {})
	states.append(_state_of("fairy_builder", "unset", d))
	n += 1
	if _lines_of(d) != expected_idle.call(1) or str(d.get("speaker", "")) != "fairy_builder":
		bad.append("unset: %s" % str(_lines_of(d)))
	for tier in range(1, 11):
		_flags(gm, {"home_tier": tier})
		d = _lr.get_dialogue("fairy_builder", {})
		states.append(_state_of("fairy_builder", "idle_%d" % tier, d))
		n += 1
		if _lines_of(d) != expected_idle.call(tier) or _has_choice(d, "home_upgrade") != (tier < 10):
			bad.append("idle_%d: %s upgrade=%s" % [tier, str(_lines_of(d)), str(_has_choice(d, "home_upgrade"))])
	for tier in range(2, 11):
		_flags(gm, {"home_tier": tier - 1, "home_building": tier})
		d = _lr.get_dialogue("fairy_builder", {})
		states.append(_state_of("fairy_builder", "building_%d" % tier, d))
		n += 1
		if _lines_of(d) != ["DLG_BUILDER_T%02d_BUILDING" % tier]:
			bad.append("building_%d: %s" % [tier, str(_lines_of(d))])
		_flags(gm, {"home_tier": tier, "home_upgrade_done": tier})
		d = _lr.get_dialogue("fairy_builder", {})
		states.append(_state_of("fairy_builder", "done_%d" % tier, d))
		n += 1
		if _lines_of(d) != ["DLG_BUILDER_T%02d_DONE" % tier]:
			bad.append("done_%d: %s" % [tier, str(_lines_of(d))])
	_flags(gm, {})
	t.check("builder_dialogue_29_branches", bad.is_empty() and n == 29, "%d flag combinations, wrong: %s" % [n, str(bad.slice(0, 3))])
	var shops_ok := true
	for npc in [["fairy_furnisher", "furniture_shop"], ["fairy_tailor", "tailor_shop"]]:
		var sd: Dictionary = _lr.get_dialogue(npc[0], {})
		states.append(_state_of(npc[0], "dialogue", sd))
		var opens := false
		for c in LuaData.arr(sd.get("choices", [])):
			var cd := LuaData.dict(c)
			opens = opens or (str(cd.get("action", "")) == "open_shop" and str(cd.get("shop_id", "")) == npc[1])
		shops_ok = shops_ok and opens and not _lines_of(sd).is_empty()
	t.expect(shops_ok, "the two shopkeeper dialogues open furniture_shop and tailor_shop")
	# review F1 r1: nothing checked the shop_id of the 29 builder buttons (a typo made the Materials button open nothing)
	var shops: Dictionary = LuaData.dict(_lr.get_shops())
	var texts := {}
	for f in ["fairy_builder", "fairy_furnisher", "fairy_tailor"]:
		texts["lua/dialogue/%s.lua" % f] = FileAccess.get_file_as_string("res://lua/dialogue/%s.lua" % f)
	var sp := ContentValidator.dialogue_shop_problems(shops, states, texts)
	var n_buttons := 0
	for st in states:
		for c in st["choices"]:
			n_buttons += 1 if str(c["action"]) == "open_shop" else 0
	t.check("dialogue_shop_buttons_open_real_shops", sp.is_empty() and states.size() == 31 and n_buttons >= 31, "%d dialogue states, %d open_shop buttons, problems: %s" % [states.size(), n_buttons, str(sp.slice(0, 3))])
	var typo_text := str(texts["lua/dialogue/fairy_builder.lua"]).replace("shop_id = \"builder_yard\"", "shop_id = \"builder_yardx\"")
	t.expect(not ContentValidator.dialogue_shop_problems(shops, [], {"lua/dialogue/fairy_builder.lua": typo_text}).is_empty(), "negative control: a shop_id typo in the Lua text of the builder is reported")
	t.expect(not ContentValidator.dialogue_shop_problems(shops, [{"npc": "fairy_builder", "label": "typo", "choices": [{"action": "open_shop", "shop_id": "builder_yardx"}]}], {}).is_empty(),
			"negative control: a flag state whose button names a shop that does not exist is reported")
	t.expect(not ContentValidator.dialogue_shop_problems(shops, [{"npc": "fairy_tailor", "label": "other keeper", "choices": [{"action": "open_shop", "shop_id": "furniture_shop"}]}], {}).is_empty(),
			"negative control: the tailor opening the furniture shop is reported")
	t.expect(not ContentValidator.dialogue_shop_problems(shops, [{"npc": "fairy_builder", "label": "done_5", "choices": [{"action": "close", "shop_id": ""}]}], {}).is_empty(),
			"negative control: a builder flag state without a shop button is reported")


# ---------------------------------------------------------------------------------------------------------- pending offers + Grant

func _load_pending_dialogues() -> bool:
	var ok := true
	for d in PENDING_DIALOGUES:
		ok = ok and _lr.load_file("res://data/features/pending/lua/dialogue/%s.lua" % d) != ""
	return ok


func _pending_offers_and_grant(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	Fresh.new_game(t)
	var loaded := _load_pending_dialogues()
	t.expect(loaded, "the three pending reference dialogues load through LuaRuntime.load_file")
	var accepted := {}
	for q in Grant.DIALOGUE_QUESTS:
		Fresh.new_game(t)
		accepted[q] = Grant.accept_via_dialogue(q) and (bool(qm.is_active(StringName(q))) if qm.has_method("is_active") else true)
	Fresh.new_game(t)
	# the offers appear at the right flag state only: Oak offers snurresvampen until it is active or done, the wizard needs the three math flags
	_flags(gm, {"snurresvampen_active": true})
	var oak_active := not _has_quest_choice(_lr.get_dialogue("guard_oak", {}), "snurresvampen")
	_flags(gm, {})
	var wiz_early := not _has_quest_choice(_lr.get_dialogue("fairy_wizard", {}), "bogtraeet")
	_flags(gm, {"home_tier": 4})
	var king_early := not _has_quest_choice(_lr.get_dialogue("fairy_king", {}), "slotsdroemmen")
	_flags(gm, {})
	t.check("pending_offers_accepted_by_dialogue", loaded and accepted == {"snurresvampen": true, "moonstone_crown": true, "bogtraeet": true, "slotsdroemmen": true} and oak_active and wiz_early and king_early, "accepted through the dialogue choice: %s; reminder-only states %s/%s/%s" % [str(accepted), str(oak_active), str(wiz_early), str(king_early)])
	# Grant.requirements for every tier, with the stand-in furniture store and the real economy / quests / flags
	Fresh.new_game(t)
	var fake := FakeFurnitureManager.new(1)
	Svc.override("FurnitureManager", fake)
	var bad: Array[String] = []
	var reports: Array[String] = []
	for n in range(2, 11):
		gm.set_flag(&"home_tier", n - 1)
		fake.set_tier(n - 1)
		var rep := Grant.requirements(n)
		if not bool(rep["ok"]):
			bad.append("tier %d: %s" % [n, str(rep["missing"])])
			continue
		var req := LuaData.dict(LuaData.dict(Grant.tier_def(n)).get("requires", {}))
		var cost := LuaData.dict(LuaData.dict(Grant.tier_def(n)).get("cost", {}))
		var eco: Node = t.autoload("EconomyManager")
		if int(eco.gold) < LuaData.int_of(cost.get("gold", 0)):
			bad.append("tier %d: gold" % n)
		for m in LuaData.int_map(cost.get("materials", {})):
			if int(eco.count_item(StringName(m))) < int(LuaData.int_map(cost["materials"])[m]):
				bad.append("tier %d: material %s" % [n, m])
		for q in LuaData.arr(req.get("quests", [])):
			if not bool(qm.is_completed(StringName(str(q)))):
				bad.append("tier %d: quest %s" % [n, q])
		for npc in LuaData.int_map(LuaData.dict(req).get("friendship", {})):
			if gm.flag_int(StringName("friend_" + str(npc)), 0) < int(LuaData.int_map(req["friendship"])[npc]):
				bad.append("tier %d: hearts of %s" % [n, npc])
		if req.has("hygge") and fake.hygge_level_index() < LuaData.int_of(req["hygge"]):
			bad.append("tier %d: hygge level %d < %d" % [n, fake.hygge_level_index(), LuaData.int_of(req["hygge"])])
		reports.append("t%d:%s" % [n, "hygge %d" % fake.hygge_score() if req.has("hygge") else "ok"])
		for m in LuaData.int_map(cost.get("materials", {})):          # what HomeManager.start_upgrade will pay
			eco.remove_item(StringName(m), int(LuaData.int_map(cost["materials"])[m]))
		eco.spend_gold(LuaData.int_of(cost.get("gold", 0)))
	t.check("grant_requirements_tiers_2_to_10", bad.is_empty(), "9 tiers granted through the public APIs (%s); problems: %s" % [", ".join(reports), str(bad.slice(0, 4))])
	# a grant for a quest that nobody offers must FAIL instead of granting it silently (RV-P1 regression).  Two ways to be unoffered, both independent of the repo's own dialogue files:
	# (a) no npc lists the quest in quests_offered; (b) the giver's dialogue has no quest_accept choice (a fixture dialogue replaces guard_oak for a moment)
	Fresh.new_game(t)
	t.expect(Grant.giver_of("nobody_offers_this") == "" and not Grant.accept_via_dialogue("nobody_offers_this"), "a quest that no npc offers is refused by accept_via_dialogue, never granted silently")
	var fixture_dir := OS.get_user_data_dir().path_join("grant_fixture")
	DirAccess.make_dir_recursive_absolute(fixture_dir)
	var fixture := fixture_dir.path_join("guard_oak.lua")
	var fh := FileAccess.open(fixture, FileAccess.WRITE)
	fh.store_string("kind = \"dialogue\"\nid = \"guard_oak\"\n\nfunction get_dialogue(context)\n  return {\n    speaker = \"guard_oak\",\n    speaker_name_key = \"NPC_GUARD_OAK\",\n    lines = { { id = \"x\", text_key = \"DIALOGUE_OAK_GREET\" } },\n    choices = { { id = \"bye\", text_key = \"DIALOGUE_CHOICE_GOODBYE\", action = \"close\" } },\n  }\nend\n")
	fh.close()
	t.expect(_lr.load_file(fixture) != "" and not Grant.accept_via_dialogue("snurresvampen"), "a giver whose dialogue has no quest_accept choice for the quest does not grant it either")
	DirAccess.remove_absolute(fixture)
	Svc.clear_overrides()
	fake.free()
	_lr.reload_scripts()
	Fresh.new_game(t)


func _has_quest_choice(d: Dictionary, quest: String) -> bool:
	for c in LuaData.arr(d.get("choices", [])):
		var cd := LuaData.dict(c)
		if str(cd.get("action", "")) == "quest_accept" and str(cd.get("quest_id", "")) == quest:
			return true
	return false


# ---------------------------------------------------------------------------------------------------------- helpers

class CountingNode extends Node:
	var resets: int = 0
	func reset() -> void:
		resets += 1


func _helpers(t) -> void:
	# Fresh.new_game resets the model AND every feature manager that exists, exactly once each
	var eco: Node = t.autoload("EconomyManager")
	var gm: Node = t.autoload("GameManager")
	var spy := CountingNode.new()
	Svc.override("HomeManager", spy)
	eco.add_gold(777)
	gm.set_flag(&"friend_mayor_lyra", 5)
	Fresh.new_game(t)
	var start_gold := LuaData.int_of(Svc.lua_config("economy.starting_gold", 500), 500)
	t.check("fresh_resets_everything", spy.resets == 1 and int(eco.gold) == start_gold and not gm.world_flags.has(&"friend_mayor_lyra"), "gold %s (start %d), flag friend_mayor_lyra %s, HomeManager.reset() called %d time(s)" % [str(eco.gold), start_gold, str(gm.get_flag(&"friend_mayor_lyra", "gone")), spy.resets])
	Svc.clear_overrides()
	spy.free()
	Fresh.jump_to_total_day(225)
	t.expect(gm.total_day() == 225, "Fresh.jump_to_total_day(225) -> total_day() %s" % str(gm.total_day()))
	Fresh.new_game(t)
	# AutoFurnish fills a tier-3 room to a hygge target through EconomyManager + the store + place_from_stock
	var fake := FakeFurnitureManager.new(3)
	Svc.override("FurnitureManager", fake)
	gm.set_flag(&"home_tier", 3)
	var placed := AutoFurnish.fill(45)
	t.check("auto_furnish_reaches_target", fake.hygge_score() >= 45 and placed > 0 and placed <= 19 and fake.room.pieces.size() == placed and fake.stock.is_empty(), "%d pieces placed (room of tier 3: 19 slots), hygge %d, stock left %s" % [placed, fake.hygge_score(), str(fake.stock)])
	var again := AutoFurnish.fill(100000)
	t.expect(fake.room.pieces.size() <= 19 and fake.stock.is_empty(), "filling past the capacity stops at the room limit (%d placed in total, nothing stray in the store)" % (placed + again))
	Svc.clear_overrides()
	fake.free()
	Fresh.new_game(t)


# ---------------------------------------------------------------------------------------------------------- review F1 r2: the binding accessor is hygge_score()

## The store + placement API of FakeFurnitureManager and NO hygge accessor at all: the two subclasses add exactly one name each, so a helper that calls the other name hits a missing method.
class StoreFacade extends Node:
	var inner: FakeFurnitureManager

	func _init(p_tier: int = 1) -> void:
		inner = FakeFurnitureManager.new(p_tier)

	func dispose() -> void:
		inner.free()

	func set_tier(p_tier: int) -> void:
		inner.set_tier(p_tier)

	func reset() -> void:
		inner.reset()

	func can_add(item_id: Variant, amount: int) -> bool:
		return inner.can_add(item_id, amount)

	func add(item_id: Variant, amount: int) -> bool:
		return inner.add(item_id, amount)

	func remove(item_id: Variant, amount: int) -> bool:
		return inner.remove(item_id, amount)

	func count_stock(item_id: Variant) -> int:
		return inner.count_stock(item_id)

	func count_total(item_id: Variant) -> int:
		return inner.count_total(item_id)

	func owned_ids() -> Array:
		return inner.owned_ids()

	func place_from_stock(item_id: Variant, cell: Vector2i, rot: int = 0) -> Dictionary:
		return inner.place_from_stock(item_id, cell, rot)

	func item_hygge(item_id: Variant) -> int:
		return inner.item_hygge(item_id)

	func hygge_level_index() -> int:
		return inner.hygge_level_index()


## what F3 ships (PLAN_FEATURES.md section 3 task 4): hygge_score() and no other name
class ScoreOnlyManager extends StoreFacade:
	func hygge_score() -> int:
		return inner.hygge_score()


## what the design prototype had: hygge_total() only
class LegacyNameManager extends StoreFacade:
	func hygge_total() -> int:
		return inner.hygge_score()


func _hygge_accessor(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var gate_tier := 0
	var gate_level := 0
	for n in range(2, 11):
		var req := LuaData.dict(LuaData.dict(Grant.tier_def(n)).get("requires", {}))
		if req.has("hygge"):
			gate_tier = n
			gate_level = LuaData.int_of(req["hygge"])
			break
	# (1) a manager with ONLY hygge_score(): AutoFurnish and Grant (a tier with a hygge gate) work against it
	Fresh.new_game(t)
	var score_only := ScoreOnlyManager.new(3)
	Svc.override("FurnitureManager", score_only)
	gm.set_flag(&"home_tier", 3)
	var placed := AutoFurnish.fill(45)
	var fill_ok := placed > 0 and score_only.hygge_score() >= 45 and not score_only.has_method("hygge_total")
	Fresh.new_game(t)
	gm.set_flag(&"home_tier", gate_tier - 1)
	score_only.set_tier(gate_tier - 1)
	var rep := Grant.requirements(gate_tier)
	var grant_ok := gate_tier > 0 and bool(rep["ok"]) and score_only.hygge_level_index() >= gate_level and int(LuaData.dict(rep["hygge"]).get("score", -1)) >= int(LuaData.dict(rep["hygge"]).get("target", 1))
	Svc.clear_overrides()
	score_only.dispose()
	score_only.free()
	# (2) a manager that only has the prototype's hygge_total(): the helpers REPORT it instead of calling a method that is not there
	Fresh.new_game(t)
	var legacy := LegacyNameManager.new(3)
	Svc.override("FurnitureManager", legacy)
	gm.set_flag(&"home_tier", gate_tier - 1)
	legacy.set_tier(gate_tier - 1)
	var rep2 := Grant.requirements(gate_tier)
	var reported := not bool(rep2["ok"]) and str(rep2["missing"]).contains("hygge_score()")
	var nothing_placed := AutoFurnish.fill(45) == 0 and legacy.inner.room.pieces.is_empty()
	Svc.clear_overrides()
	legacy.dispose()
	legacy.free()
	Fresh.new_game(t)
	# (3) no helper CALLS hygge_total; the stand-in keeps the old name only as an alias of hygge_score()
	var calls: Array[String] = []
	for f in ["grant", "auto_furnish", "room_model", "fresh", "content_validator"]:
		var text := FileAccess.get_file_as_string("res://tests/lib/features/%s.gd" % f)
		if text.contains(".hygge_total(") or text.contains("\"hygge_total\""):
			calls.append(f)
	var fake_text := FileAccess.get_file_as_string("res://tests/lib/features/fake_furniture.gd")
	var alias_ok := fake_text.contains("func hygge_score() -> int:") and fake_text.contains("func hygge_total() -> int:\n\treturn hygge_score()")
	t.check("hygge_accessor_is_hygge_score", fill_ok and grant_ok and reported and nothing_placed and calls.is_empty() and alias_ok,
			"fill %s (%d pieces), grant tier %d %s, legacy-only manager reported %s / nothing placed %s, helpers calling hygge_total: %s, alias %s" % [str(fill_ok), placed, gate_tier, str(grant_ok), str(reported), str(nothing_placed), str(calls), str(alias_ok)])


# ---------------------------------------------------------------------------------------------------------- review F1 r2: references and numbers that no rule looked at

func _spot_source_quests() -> Dictionary:
	var out := {}
	for id in _feature_ids():
		for src in LuaData.arr(_lr.get_item_def(id).get("sources", [])):
			var sd := LuaData.dict(src)
			if str(sd.get("kind", "")) == "spot":
				out[str(sd.get("spot", ""))] = str(sd.get("quest", ""))
	return out


func _feature_quests() -> Dictionary:
	var out := {}
	for q in ["bogtraeet", "moonstone_crown", "snurresvampen", "slotsdroemmen"]:
		var path := "res://lua/quests/%s.lua" % q
		var parsed: Dictionary = _lr.parse_lua_source(FileAccess.get_file_as_string(path), path)
		out[q] = {"rewards": LuaData.dict(parsed.get("rewards", {})), "objectives": LuaData.arr(parsed.get("objectives", [])), "meta": LuaData.dict(parsed.get("meta", {}))}
	return out


func _review2_rules(t) -> void:
	var loot := LuaData.dict(_lr.get_config("loot", {}))
	# --- loot.spots.*.requires (an unknown quest id made a keepsake unobtainable and every check stayed green)
	var spots := LuaData.dict(loot.get("spots", {}))
	var source_quest := _spot_source_quests()
	var quest_exists := func(q: String) -> bool: return _lr.has_script("quests/" + q)
	var with_requires := 0
	for sid in spots:
		with_requires += 1 if LuaData.dict(spots[sid]).has("requires") else 0
	var spot_problems := ContentValidator.spot_requirement_problems(spots, quest_exists, source_quest)
	t.check("spot_requirements_valid", spot_problems.is_empty() and with_requires >= 5, "%d of %d spots have requirements; problems: %s" % [with_requires, spots.size(), str(spot_problems.slice(0, 3))])
	for op in ["unknown_quest", "day_zero", "tier_eleven", "unknown_key", "source_names_other_quest", "empty_quests", "day_text", "source_without_requires"]:
		t.expect(not ContentValidator.spot_requirement_problems(_spots_after(spots, op), quest_exists, source_quest).is_empty(), "negative control: the spot requirement defect '%s' is reported" % op)
	# --- the npc / item references of the quests
	var npcs := LuaData.dict(_lr.get_config("npcs", {}))
	var item_exists := func(i: String) -> bool: return not _lr.get_item_def(i).is_empty()
	var quests := _feature_quests()
	var qp := ContentValidator.quest_reference_problems(quests, npcs, item_exists)
	t.check("quest_references_valid", qp.is_empty() and quests.size() == 4, "%d quests, problems: %s" % [quests.size(), str(qp.slice(0, 3))])
	for op in ["friendship_npc", "hearts_zero", "hearts_eleven", "giver", "objective_npc", "reward_item", "gold_negative"]:
		t.expect(not ContentValidator.quest_reference_problems(_quests_after(quests, op), npcs, item_exists).is_empty(), "negative control: the quest reference defect '%s' is reported" % op)
	# --- max_stack (ordinary furniture 9, keepsakes 1) and decor
	var defs := {}
	for id in _feature_ids():
		defs[id] = _lr.get_item_def(id).duplicate(true)
	var stack := ContentValidator.stack_problems(defs)
	t.check("furniture_max_stack_rule", stack.is_empty(), "%d ids, problems: %s" % [defs.size(), str(stack.slice(0, 3))])
	var broken := defs.duplicate(true)
	(broken["bed_pine"] as Dictionary)["max_stack"] = 99
	t.expect(not ContentValidator.stack_problems(broken).is_empty(), "negative control: max_stack 99 on an ordinary bed is reported")
	broken = defs.duplicate(true)
	(broken["bed_moon"] as Dictionary)["max_stack"] = 9
	t.expect(not ContentValidator.stack_problems(broken).is_empty(), "negative control: max_stack 9 on a keepsake is reported")
	broken = defs.duplicate(true)
	(broken["bed_pine"] as Dictionary)["max_stack"] = 8
	t.expect(not ContentValidator.stack_problems(broken).is_empty(), "negative control: max_stack 8 on an ordinary bed is reported")
	var keep_decor: Variant = _lr.get_item_def("bed_moon").get("decor", 0)
	_lr.get_item_def("bed_moon")["decor"] = 0
	var v_decor := ContentValidator.new()
	v_decor.run()
	_lr.get_item_def("bed_moon")["decor"] = keep_decor
	var decor_seen := false
	for e in v_decor.errors:
		decor_seen = decor_seen or (e.contains("bed_moon") and e.contains("decor"))
	t.expect(decor_seen, "negative control: a legendary piece with decor 0 is reported (%s)" % str(v_decor.errors.slice(0, 1)))
	# --- shop numbers
	var shops: Dictionary = LuaData.dict(_lr.get_shops())
	var sp := ContentValidator.shop_stock_problems(shops)
	t.check("shop_stock_numbers_valid", sp.is_empty(), "%d shops, problems: %s" % [shops.size(), str(sp.slice(0, 3))])
	for op in ["stock_negative", "stock_zero", "restock_above_stock", "restock_text", "period_zero", "price_mult_zero", "season_boost_half"]:
		t.expect(not ContentValidator.shop_stock_problems(_shops_after(shops, op)).is_empty(), "negative control: the shop number defect '%s' is reported" % op)
	# --- wardrobe z order
	var slots := LuaData.dict(LuaData.dict(_lr.get_config("wardrobe", {})).get("equip_slots", {}))
	var zp := ContentValidator.equip_slot_problems(slots)
	t.check("wardrobe_equip_slot_z_distinct", zp.is_empty() and slots.size() == 9, "%d slots, problems: %s" % [slots.size(), str(zp.slice(0, 3))])
	var bs := slots.duplicate(true)
	(bs["circlet"] as Dictionary)["z"] = (bs["hat"] as Dictionary)["z"]
	t.expect(not ContentValidator.equip_slot_problems(bs).is_empty(), "negative control: the circlet on the z of the hat is reported")
	bs = slots.duplicate(true)
	(bs["circlet"] as Dictionary)["z"] = "top"
	t.expect(not ContentValidator.equip_slot_problems(bs).is_empty(), "negative control: a z that is not a number is reported")
	# --- voice keys of the three dialogues
	var dlg := {}
	for f in ContentValidator.FEATURE_DIALOGUES:
		dlg["lua/dialogue/%s.lua" % f] = FileAccess.get_file_as_string("res://lua/dialogue/%s.lua" % f)
	var vp := ContentValidator.voice_key_problems(dlg)
	t.check("voice_keys_follow_speaker_and_line", vp.is_empty(), "%d dialogue files, problems: %s" % [dlg.size(), str(vp.slice(0, 3))])
	var furn := str(dlg["lua/dialogue/fairy_furnisher.lua"])
	t.expect(not ContentValidator.voice_key_problems({"f.lua": furn.replace("voice/fairy_furnisher/greet", "voice/fairy_furnisher/gret")}).is_empty(), "negative control: voice key voice/fairy_furnisher/gret is reported")
	t.expect(not ContentValidator.voice_key_problems({"f.lua": furn.replace("voice_key = \"voice/fairy_furnisher/greet\",", "")}).is_empty(), "negative control: a spoken line without voice_key is reported")
	t.expect(not ContentValidator.voice_key_problems({"f.lua": furn.replace("voice/fairy_furnisher/greet", "voice/fairy_tailor/greet")}).is_empty(), "negative control: another speaker's voice key is reported")
	t.expect(not ContentValidator.voice_key_problems({"f.lua": furn.replace("DLG_FURNISHER_GREET", "DLG_FURNISHER_HELLO")}).is_empty(), "negative control: a line id that does not match its text key is reported")
	# --- no text literals in the Lua of this package
	var texts := {}
	for f in F1_LUA:
		texts[f] = FileAccess.get_file_as_string("res://" + f)
	var tl := ContentValidator.text_literal_problems(texts)
	t.check("no_text_literals_in_f1_lua", tl.is_empty() and texts.size() == F1_LUA.size(), "%d files, text literals: %s" % [texts.size(), str(tl.slice(0, 3))])
	var quest_text := str(texts["lua/quests/bogtraeet.lua"])
	t.expect(not ContentValidator.text_literal_problems({"q.lua": quest_text.replace("description_key =", "description = \"Fortæl Zephyr, at du kan regne\",\n    description_key =")}).is_empty(), "negative control: a Danish description literal in a quest is reported")
	t.expect(ContentValidator.text_literal_problems({"q.lua": "-- a comment with \"quoted words\" in it\nx = \"voice/a_b\"\ny = \"Find the stone\" -- one text\n"}).size() == 1, "a comment is skipped, a path is not text, a literal with a space is")
	# --- loot creature name keys: defined, or pending behind a CSV that has not landed (documented), never a typo
	var creatures := LuaData.dict(loot.get("creatures", {}))
	var owners: Dictionary = _lm.load_owners("res://")
	var defined := func(k: String) -> bool: return _lm.has_key(k)
	var owner_of := func(k: String) -> String: return _lm.owner_of(k, owners)
	var file_exists := func(f: String) -> bool: return FileAccess.file_exists("res://localization/" + f)
	var cres := ContentValidator.creature_key_problems(creatures, defined, owner_of, file_exists)
	t.check("creature_name_keys_defined_or_pending", (cres["problems"] as Array).is_empty() and creatures.size() == 3,
			"%d creatures, %d pending behind a CSV that has not landed: %s; problems: %s" % [creatures.size(), (cres["pending"] as Array).size(), str(cres["pending"]), str(cres["problems"])])
	var typo := {"bat": {"name_key": "ENEMYBAT"}}
	t.expect(not (ContentValidator.creature_key_problems(typo, defined, owner_of, file_exists)["problems"] as Array).is_empty(), "negative control: a creature key that no CSV owns (typo) is reported")
	var forgot := {"x": {"name_key": "GAME_NO_SUCH_CREATURE"}}
	t.expect(not (ContentValidator.creature_key_problems(forgot, defined, owner_of, file_exists)["problems"] as Array).is_empty(), "negative control: a key whose owner file EXISTS but has no row is reported")
	var not_yet := ContentValidator.creature_key_problems(forgot, defined, owner_of, func(_f: String) -> bool: return false)
	t.expect((not_yet["problems"] as Array).is_empty() and (not_yet["pending"] as Array).size() == 1, "an owner CSV that has not landed makes the key PENDING, not a failure")
	t.expect(not (ContentValidator.creature_key_problems({"x": {"name_key": "enemy bat"}}, defined, owner_of, file_exists)["problems"] as Array).is_empty(), "negative control: a name_key that is not an upper-case key is reported")


## the loot spots with ONE requirement defect (deep copy: the runtime data is never touched)
func _spots_after(spots: Dictionary, op: String) -> Dictionary:
	var m := spots.duplicate(true)
	var cat := m["mis_hjoerne"] as Dictionary
	var tier := m["trae_hulning"] as Dictionary
	var day := m["fuglehuset"] as Dictionary
	match op:
		"unknown_quest":
			cat["requires"] = {"quests": ["lost_catx"]}
		"day_zero":
			day["requires"] = {"day_min": 0}
		"tier_eleven":
			tier["requires"] = {"home_tier_min": 11}
		"unknown_key":
			day["requires"] = {"day_min": 14, "season": "vinter"}
		"source_names_other_quest":
			cat["requires"] = {"quests": ["moonstone_crown"]}
		"empty_quests":
			cat["requires"] = {"quests": []}
		"day_text":
			day["requires"] = {"day_min": "14"}
		"source_without_requires":
			cat.erase("requires")
	return m


func _quests_after(quests: Dictionary, op: String) -> Dictionary:
	var m := quests.duplicate(true)
	var q := m["moonstone_crown"] as Dictionary
	match op:
		"friendship_npc":
			(q["rewards"] as Dictionary)["friendship"] = {"fairy_kingx": 2}
		"hearts_zero":
			(q["rewards"] as Dictionary)["friendship"] = {"fairy_king": 0}
		"hearts_eleven":
			(q["rewards"] as Dictionary)["friendship"] = {"fairy_king": 11}
		"giver":
			(q["meta"] as Dictionary)["giver"] = "fairy_kingx"
		"objective_npc":
			((q["objectives"] as Array)[1] as Dictionary)["npc"] = "fairy_kingx"
		"reward_item":
			(q["rewards"] as Dictionary)["items"] = {"circlet_moon_crownx": 1}
		"gold_negative":
			(q["rewards"] as Dictionary)["gold"] = -5
	return m


func _shops_after(shops: Dictionary, op: String) -> Dictionary:
	var m := shops.duplicate(true)
	var fs := (m["furniture_shop"] as Dictionary)
	var row := ((fs["stock"] as Dictionary)["bed_pine"] as Dictionary)
	var slot := ((fs["rotation"] as Array)[0] as Dictionary)
	match op:
		"stock_negative":
			row["stock"] = -3
		"stock_zero":
			row["stock"] = 0
		"restock_above_stock":
			row["restock"] = 9
		"restock_text":
			row["restock"] = "two"
		"period_zero":
			slot["period"] = 0
		"price_mult_zero":
			slot["price_mult"] = 0
		"season_boost_half":
			slot["season_boost"] = 0.5
	return m


# ---------------------------------------------------------------------------------------------------------- add_autoload tool

func _autoload_tool(t) -> void:
	var script := ProjectSettings.globalize_path("res://tools/features/test_add_autoload.py")
	var res: Dictionary = t.run_tool("/usr/bin/env", PackedStringArray(["python3", "-I", script, "--project", ProjectSettings.globalize_path("res://project.godot")]))
	var ids: Dictionary = t.parse_tool_ids(res)
	var need := ["add_all", "second_run_is_noop", "base_block_untouched", "added_after_animal_husbandry", "skips_missing_scripts", "parallel_runs_do_not_corrupt", "refuses_other_path", "refuses_foreign_entry", "dry_run_writes_nothing",
			"dedupes_repeated_names", "refuses_duplicate_entry", "refuses_missing_project", "refuses_missing_project_creates_no_lock", "refuses_missing_root", "refuses_unreadable_project"]
	var missing: Array[String] = []
	for n in need:
		if not (n in ids["pass"]):
			missing.append(n)
	t.check("add_autoload_idempotent_and_parallel_safe", missing.is_empty() and (ids["fail"] as Array).is_empty() and int(res.get("code", -1)) == 0, "python self-test: %d pass, fails %s, missing %s" % [(ids["pass"] as Array).size(), str(ids["fail"]), str(missing)])
	# P01's own rule accepts what the tool writes: run the tool on a COPY of project.godot with fake scripts, then check_project.gd in text mode on the copy
	var dir := OS.get_user_data_dir().path_join("add_autoload_copy")
	DirAccess.make_dir_recursive_absolute(dir)
	var copy := dir.path_join("project.godot")
	var f := FileAccess.open(copy, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string("res://project.godot"))
	f.close()
	for rel in ["scripts/home/home_manager.gd", "scripts/furniture/furniture_manager.gd", "scripts/wardrobe/wardrobe_manager.gd", "scripts/loot/loot_service.gd", "scripts/collection/collection_log.gd"]:
		DirAccess.make_dir_recursive_absolute(dir.path_join(rel.get_base_dir()))
		var g := FileAccess.open(dir.path_join(rel), FileAccess.WRITE)
		g.store_string("extends Node\n")
		g.close()
	var tool_path := ProjectSettings.globalize_path("res://tools/features/add_autoload.py")
	var r1: Dictionary = t.run_tool("/usr/bin/env", PackedStringArray(["python3", "-I", tool_path, "--project", copy]))
	var text1 := FileAccess.get_file_as_string(copy)
	var r2: Dictionary = t.run_tool("/usr/bin/env", PackedStringArray(["python3", "-I", tool_path, "--project", copy]))
	var checked: Dictionary = t.run_godot_script("res://tests/tools/check_project.gd", PackedStringArray(["--text=" + copy]))
	var cids: Dictionary = t.parse_tool_ids(checked)
	t.check("add_autoload_result_accepted_by_check_project", int(r1.get("code", -1)) == 0 and int(r2.get("code", -1)) == 0 and FileAccess.get_file_as_string(copy) == text1 and text1.count("res://scripts/") >= 5 \
			and "p01.autoloads_base_in_order_features_after" in cids["pass"] and (cids["fail"] as Array).is_empty(), "tool exit %s/%s, second run unchanged %s, check_project: %s" % [str(r1.get("code")), str(r2.get("code")), str(FileAccess.get_file_as_string(copy) == text1), str(cids)])
	DirAccess.remove_absolute(copy)


## tools/features/test_rename_town.py (python, on temp copies): review F1 r2 - an empty / blank --old with --apply used to rewrite every text file; .map and .svg were never rewritten
func _rename_tool(t) -> void:
	var script := ProjectSettings.globalize_path("res://tools/features/test_rename_town.py")
	var res: Dictionary = t.run_tool("/usr/bin/env", PackedStringArray(["python3", "-I", script]))
	var ids: Dictionary = t.parse_tool_ids(res)
	var need := ["refuses_empty_old_with_apply", "refuses_blank_old", "refuses_empty_new", "dry_run_changes_nothing", "apply_renames_all_case_variants", "covers_map_svg_tscn_tres_gdshader", "leaves_binary_and_skip_dirs", "second_apply_is_noop"]
	var missing: Array[String] = []
	for n in need:
		if not (n in ids["pass"]):
			missing.append(n)
	t.check("rename_town_refuses_blank_old_and_covers_maps", missing.is_empty() and (ids["fail"] as Array).is_empty() and int(res.get("code", -1)) == 0, "python self-test: %d pass, fails %s, missing %s" % [(ids["pass"] as Array).size(), str(ids["fail"]), str(missing)])


# ---------------------------------------------------------------------------------------------------------- the rule helpers of the offline validator, seen failing

## tools/features/validate/rules_selftest.py (python, about a second): the helpers of the validator rules N1 / SH1 / S10 / MM1 on synthetic defects.  N1 was vacuous for the default stage path
## (the filter tested the absolute path): the self-test builds exactly such a tree and expects the name to be found there.
func _rules_selftest(t) -> void:
	var script := ProjectSettings.globalize_path("res://tools/features/validate/rules_selftest.py")
	var res: Dictionary = t.run_tool("/usr/bin/env", PackedStringArray(["python3", "-I", script]))
	var ids: Dictionary = t.parse_tool_ids(res)
	var passed: Array = ids["pass"]
	var failed: Array = ids["fail"]
	for g in [["n1_", 11, "rules_selftest_n1_scan_not_vacuous_below_stage_path"], ["sh1_", 9, "rules_selftest_shop_opening_days"], ["s10_", 8, "rules_selftest_dialogue_shop_buttons"], ["mm1_", 14, "rules_selftest_map_markers"],
			["r21_", 9, "rules_selftest_spot_requirements"], ["q5_", 7, "rules_selftest_quest_references"], ["c19_", 7, "rules_selftest_stack_rule"], ["c20_", 4, "rules_selftest_decor_rule"], ["sh2_", 9, "rules_selftest_shop_stock_numbers"],
			["r7d_", 4, "rules_selftest_equip_slot_z"], ["k10_", 7, "rules_selftest_voice_keys"], ["k9_", 7, "rules_selftest_creature_keys"], ["d6_", 7, "rules_selftest_text_literals"]]:
		var n_pass := 0
		var n_fail := 0
		for id in passed:
			n_pass += 1 if str(id).begins_with(str(g[0])) else 0
		for id in failed:
			n_fail += 1 if str(id).begins_with(str(g[0])) else 0
		t.check(str(g[2]), n_fail == 0 and n_pass >= int(g[1]), "%d of %d helper checks pass, %d fail" % [n_pass, int(g[1]), n_fail])
	t.check("rules_selftest_exit_code", int(res.get("code", -1)) == 0 and failed.is_empty(), "exit %s, failing ids %s" % [str(res.get("code", "?")), str(failed)])


# ---------------------------------------------------------------------------------------------------------- the offline gate exists

func _validator_gate(t) -> void:
	var needed := ["tools/features/test_rename_town.py", "tools/features/test_add_autoload.py", "tools/features/validate/run_validate.sh", "tools/features/validate/validate.py", "tools/features/validate/validate_godot.gd", "tools/features/validate/stage.py", "tools/features/validate/stage.manifest",
		"tools/features/validate/mutation_test.py", "tools/features/validate/stage_selftest.py", "tools/features/validate/rules_selftest.py", "tools/features/add_autoload.py", "tools/features/rename_town.py", "tools/features/merge_pending_rewards.py",
		"tools/features/sim/balance_sim.py", "docs/features/DELTAS.md", "docs/features/STAGES.md", "docs/features/BALANCE.md", "docs/features/SCHEMA.md", "docs/features/evidence/colour_check.json"]
	var missing: Array[String] = []
	for f in needed:
		if not FileAccess.file_exists("res://" + f):
			missing.append(f)
	t.check("validator_gate_files_exist", missing.is_empty(), "missing: %s" % str(missing))
	# the stage manifest names every file the validator reads from the repo: the 18 Lua files of this package are all listed (own lines), nothing of F1 is outside the manifest
	var manifest := FileAccess.get_file_as_string("res://tools/features/validate/stage.manifest")
	var unlisted: Array[String] = []
	for f in F1_LUA:
		var base: String = str(f).get_file().get_basename()
		if not manifest.contains(base) and not (str(f).begins_with("lua/data/") and manifest.contains("lua/data/**")):
			unlisted.append(f)
	t.check("stage_manifest_covers_the_package", unlisted.is_empty(), "not named in stage.manifest: %s" % str(unlisted))
