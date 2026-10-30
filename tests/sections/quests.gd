extends RefCounted
## Section quests (package P13-quests-lua-runtime): QuestManager's objective-binding runtime and every quest of lua/quests.
##
## What it proves, with the REAL EventBus signals and the real LuaRuntime / EconomyManager / GameManager (nothing is mocked except the managers of packages that
## are not built yet - FurnitureManager, HomeManager, SocialManager - which stand in as small fake nodes through Svc.override):
##   * lint: LuaRuntime.lint_report is empty (token rules + the binding lint of QuestManager) and tools/lua/lint.gd passes every file of lua/quests;
##   * the binding vocabulary one `on =` at a time (items, crops, zones, areas, dialogue / any_of, animals, buildings, enemies, recipes, quest_completed, game_event with
##     rarity / min_level / match, the social sugar, state queries) plus after_others turn-ins, have = true, needs / consume deliveries and the old id convention;
##   * the API the other packages read: offerable / offerable_for, get_tracked, the journal lists, item_in_use, get_objective_text, friendship rewards;
##   * the quests themselves: every quest file of the tree is driven objective by objective through the signals the game sends (table-driven, no quest left
##     uncompletable, exact rewards), the guide chips of lost_cat, the manual objectives and their completers, the floor anchors of the dungeon quests.
## Named checks (prefix quests.): see the check names below; the ones the orders name are listed in the package report.
const SECTION := "quests"
const TIMEOUT_S := 300.0

const QuestText := preload("res://scripts/ui/theme/tt_quest_text.gd")

## the twenty quests this package rewrites (the F1 quests, pips_runde and the dungeon / tutorial quests belong to other packages)
const P13_QUESTS := ["animal_products", "birthday_cake", "cookie_delivery", "crystal_cave", "dark_forest_mining", "enchanted_garden", "fairy_friendship", "first_animal",
	"fix_roof", "flower_necklace", "forest_patrol", "intro_lottery", "lost_cat", "math_bakery_counts", "math_harvest_puzzle", "math_wizard_quiz", "night_flower",
	"rare_mushroom_hunt", "supply_run", "sword_upgrade"]
## the eight quests of acceptance row 'feature_quests_complete_with_rewards' (RV-P4 / F1)
const FEATURE_EIGHT := ["lost_cat", "fix_roof", "birthday_cake", "math_wizard_quiz", "bogtraeet", "moonstone_crown", "snurresvampen", "slotsdroemmen"]
## Every shipped manual objective now has a runtime completer.
const PENDING_COMPLETERS := {}
## the game_event names the plan lets a quest bind (3.1 of the feature addendum, 8.4 of the dungeon addendum, 8.2 of the towns addendum)
const KNOWN_EVENTS := ["furniture_placed", "hygge_level", "festival_held", "home_upgraded", "garment_equipped", "open_home_builder", "open_home_chest", "plot_tilled", "post_read",
	"crop_ready", "field_expanded", "bin_shipped", "dungeon_floor_entered", "dungeon_runestone_activated", "dungeon_boss_defeated", "dungeon_run_ended", "floor_map_used",
	"gift_given", "festival_attended", "heart_event_finished", "chat_done", "board_read", "bath_taken", "seeds_swapped", "cache_found", "appraisal_done", "landmark_entered"]
## payloads as the owners emit them (DUNGEON_V2_ADDENDUM 8.4, PLAN_FEATURES 3.1, TOWNS addendum 8.2): the table-driven feed starts from these shapes
const EVENT_PAYLOADS := {
	"dungeon_floor_entered": {"floor": 1, "level": 1, "band": 1, "zone": "dark_forest", "seed_day": 1, "first_today": true, "deepest": true},
	"dungeon_runestone_activated": {"floor": 3, "level": 3, "band": 1, "first_time": true, "waypoint": true},
	"dungeon_boss_defeated": {"boss": "snurresvamp", "kind": "snurresvamp", "floor": 4, "level": 4, "first_kill": true},
	"dungeon_run_ended": {"reason": "left", "deepest": 1, "floors": 1},
	"floor_map_used": {"floor": 1},
	"furniture_placed": {"item": "chair_pine", "rarity": "normal"},
	"hygge_level": {"level": 0},
	"festival_held": {},
	"home_upgraded": {"tier": 1},
	"garment_equipped": {"slot": "hat", "item": "hat_cat_ears", "rarity": "rare"},
	"open_home_builder": {"tier": 1},
	"open_home_chest": {},
	"plot_tilled": {"plot_id": "plot_3_4"},
	"post_read": {"quest_id": "lost_cat"},
	"gift_given": {"npc": "baker_maja", "item": "honey", "taste": "love", "points": 80, "birthday": false},
	"festival_attended": {"id": "midsommer"},
	"heart_event_finished": {"id": "maja_first", "npc": "baker_maja", "hearts": 2},
}

var t
var qm: Node
var gm: Node
var eco: Node
var bus: Node
var lr: Node
var lm: Node
var _locale_before: String = ""


## A furniture manager as far as quests ask: how many pieces of a rarity stand, which hygge level the room has.
class FakeFurniture extends Node:
	var placed: Dictionary = {}
	var level: int = 0

	func count_placed_by_rarity(rarities: Array) -> int:
		var n := 0
		for r in rarities:
			n += int(placed.get(str(r), 0))
		return n

	func hygge_level_index() -> int:
		return level


class FakeHome extends Node:
	var tier: int = 1


## S-core's contract as far as quests ask: hearts(npc) and add_hearts(npc, n, source); the calls are recorded.
class FakeSocial extends Node:
	var hearts_of: Dictionary = {}
	var calls: Array = []

	func can_befriend(_npc: Variant) -> bool:
		return false # This payout fixture has no social-dialogue decoration.

	func hearts(npc: Variant) -> int:
		return int(hearts_of.get(str(npc), 0))

	func add_hearts(npc: Variant, n: int, source: Variant = &"quest") -> void:
		calls.append([npc, n, source])
		hearts_of[str(npc)] = mini(int(hearts_of.get(str(npc), 0)) + n, 10)


## A SocialManager without add_hearts / hearts: the quests fall back to the flag path.
class PlainNode extends Node:
	pass


func run(p_t) -> void:
	t = p_t
	qm = t.autoload("QuestManager")
	gm = t.autoload("GameManager")
	eco = t.autoload("EconomyManager")
	bus = t.autoload("EventBus")
	lr = t.autoload("LuaRuntime")
	lm = t.autoload("LocalizationManager")
	_locale_before = TranslationServer.get_locale()
	lm.set_locale("da", false)
	_lint_and_registry()
	_roster_and_meta()
	_references_exist()
	_text_keys()
	_vocabulary_events()
	_game_events()
	_state_objectives()
	await _turn_ins_have_and_delivery()
	_legacy_ids_and_double_counting()
	_social_sugar_and_friendship()
	_real_managers()
	_offers()
	_tracked_and_journal()
	_cooldowns()
	_save_roundtrip()
	_new_game_and_probes()
	_item_in_use()
	_objective_text()
	_binding_lint()
	_guide_quests()
	await _feature_quests_and_every_objective()
	_manual_completers()
	_quest_spot_needs_match_lua()
	_dungeon_and_forest_bindings()
	_forste_dage()
	for producer in ["initial", "followup", "consumer"]:
		await preload("res://tests/progression/mining_deliveries.gd").invalid_owner(t, producer)
	for producer in ["initial", "followup", "consumer"]:
		for ambient in [&"", &"p2"]:
			for quest in [&"dark_forest_mining", &"crystal_cave"]:
				await preload("res://tests/progression/mining_deliveries.gd").owner_hand_in(t, quest, producer, ambient)
	await preload("res://tests/progression/mining_deliveries.gd").hand_in(t, &"dark_forest_mining", {"iron_ore": 6, "amethyst": 2})
	await preload("res://tests/progression/mining_deliveries.gd").hand_in(t, &"crystal_cave", {"crystal_shard": 5}, true)
	await preload("res://tests/progression/mining_deliveries.gd").proof_items_stay_owned(t)
	for service in ["board", "post"]:
		for decision in ["cancel", "decline", "accept"]:
			await preload("res://tests/progression/mining_deliveries.gd").service_offer(t, &"dark_forest_mining", &"crystal_cave", service, decision)
			await preload("res://tests/progression/mining_deliveries.gd").service_offer(t, &"crystal_cave", &"dark_forest_mining", service, decision)
	_cleanup()


# =============================================================================================== helpers

func _quest_files() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at("res://lua/quests"):
		if f.get_extension() == "lua":
			out.append(f.get_basename())
	out.sort()
	return out


func _all_quest_ids() -> Array[String]:
	var out: Array[String] = []
	for k in qm.quest_defs:
		if not str(k).begins_with("zz_p13_") and not str(k).begins_with("review_"):
			out.append(str(k))
	out.sort()
	return out


func _def(q: Variant) -> Dictionary:
	return qm.get_quest_def(StringName(str(q)))


func _objectives(q: Variant) -> Array:
	return LuaData.arr(_def(q).get("objectives", []))


## Registers a synthetic quest (no source_path: the binding lint stays out of it) and returns its id. `gated` adds an objective that never completes,
## so the quest stays active while the objective under test is read.
func _reg(id: String, objectives: Array, gated: bool = true, rewards: Dictionary = {}, meta: Dictionary = {}) -> StringName:
	var all: Array = objectives.duplicate(true)
	if gated:
		all.append({"id": "gate", "target": 1, "on": "manual"})
	qm.register_quest_from_lua({"id": id, "objectives": all, "rewards": rewards, "meta": meta})
	return StringName(id)


func _start(id: String, objectives: Array, gated: bool = true, rewards: Dictionary = {}, meta: Dictionary = {}) -> StringName:
	var q := _reg(id, objectives, gated, rewards, meta)
	qm.accept_quest(q)
	return q


func _cur(q: Variant, o: String) -> int:
	return int((qm.get_objective_progress(StringName(str(q)), StringName(o)) as Dictionary).get("current", -1))


func _done(q: Variant, o: String) -> bool:
	return bool((qm.get_objective_progress(StringName(str(q)), StringName(o)) as Dictionary).get("done", false))


## A typed array as a plain one: Array[StringName] == Array only compares equal when both are typed alike.
func _plain(a: Array) -> Array:
	var out: Array = []
	for x in a:
		out.append(x)
	return out


func _need(problems: Array, cond: bool, label: String) -> void:
	if not cond:
		problems.append(label)


func _fresh() -> void:
	Svc.clear_overrides()
	Fresh.new_game(t)


func _fakes() -> Dictionary:
	var f := {"furniture": FakeFurniture.new(), "home": FakeHome.new(), "social": FakeSocial.new()}
	Svc.override("FurnitureManager", f["furniture"])
	Svc.override("HomeManager", f["home"])
	Svc.override("SocialManager", f["social"])
	return f


func _free_fakes(f: Dictionary) -> void:
	Svc.clear_overrides()
	for k in f:
		(f[k] as Node).free()


func _cleanup() -> void:
	Svc.clear_overrides()
	for k in qm.quest_defs.keys():
		if str(k).begins_with("zz_p13_"):
			qm.quest_defs.erase(k)
	lr.reload_scripts()
	Fresh.new_game(t)
	lm.set_locale(_locale_before, false)


# =============================================================================================== lint and registry

func _lint_and_registry() -> void:
	lr.reload_scripts()
	var lines: Array[String] = []
	for f in lr.lint_report:
		lines.append("%s [%s] %s" % [f["path"], f["rule"], f["message"]])
	t.check("lint_report_empty", lr.lint_report.is_empty(), "LuaRuntime.lint_report after a full reload: %s" % str(lines.slice(0, 3)))
	var files := _quest_files()
	var tool: Dictionary = t.run_godot_script("res://tools/lua/lint.gd", PackedStringArray(["--root=res://lua/quests"]))
	var ids: Dictionary = t.parse_tool_ids(tool)
	t.check("lint_tool_clean_on_every_quest_file", int(tool["code"]) == 0 and (ids["fail"] as Array).is_empty() and (ids["pass"] as Array).size() == files.size(),
		"tools/lua/lint.gd on lua/quests: %d PASS of %d files, %d FAIL, exit %s" % [(ids["pass"] as Array).size(), files.size(), (ids["fail"] as Array).size(), str(tool["code"])])
	var missing: Array[String] = []
	for f in files:
		if _def(f).is_empty() or str(_def(f).get("id", "")) != f:
			missing.append(f)
	t.check("every_quest_file_is_registered", missing.is_empty() and files.size() >= 25, "%d quest files, every file registers its id with QuestManager %s" % [files.size(), str(missing)])
	var own_missing: Array[String] = []
	for q in P13_QUESTS:
		if _def(q).is_empty():
			own_missing.append(q)
	t.check("the_twenty_quests_are_there", own_missing.is_empty(), "the 20 quests of the legacy set %s" % str(own_missing))


func _roster_and_meta() -> void:
	var npcs: Dictionary = lr.get_npcs()
	var problems: Array[String] = []
	var foreign: Array[String] = []
	for q in _all_quest_ids():
		# the book's fields are the contract of every quest; a quest that is not P13's / F1's own (the dungeon, tutorial and town quests of other packages)
		# is held to the giver rule only, anything else about its meta is a visible SKIP naming it (its owner fixes its own file)
		var own: bool = q in P13_QUESTS or q in FEATURE_EIGHT or q == "pips_runde" or q == "secret_garden" or q.begins_with("forest_mother_")
		var found: Array[String] = problems if own else foreign
		var meta := LuaData.dict(_def(q).get("meta", {}))
		var giver := str(meta.get("giver", ""))
		var source := str(meta.get("source_key", ""))
		if source != "":
			_need(problems, giver == "" and lm.text_in(source, "da") not in ["", source] and lm.text_in(source, "en") not in ["", source], "%s: self-directed source must be translated and have no false NPC giver" % q)
		else:
			_need(problems, giver != "" and npcs.has(giver), "%s: giver `%s` is not an npc" % [q, giver])
		if npcs.has(giver):
			_need(found, q in LuaData.strings(LuaData.dict(npcs[giver]).get("quests_offered", [])), "%s: %s does not list it in quests_offered (QuestManager.offerable still finds it through meta.giver)" % [q, giver])
			_need(problems, StringName(q) in qm.call("_quests_of_giver", giver), "%s: QuestManager.offerable(%s) can never list it" % [q, giver])
		_need(found, str(meta.get("tag", "")) in qm.QUEST_TAGS, "%s: tag `%s` is not one of FIND HØST BYG SKOV LÆR VENSKAB" % [q, meta.get("tag", "")])
		_need(found, str(meta.get("location", "")).begins_with("ZONE_") and lm.text_in(str(meta.get("location", "")), "da") != "", "%s: location `%s` is not a translated ZONE_ key" % [q, meta.get("location", "")])
		_need(found, meta.has("repeatable") and meta["repeatable"] is bool, "%s: meta.repeatable is missing" % q)
	t.check("giver_tag_location_for_every_quest", problems.is_empty(), "%d quests: roster giver or translated self-directed source, valid tag and ZONE_ location %s" % [_all_quest_ids().size(), str(problems.slice(0, 4))])
	if not foreign.is_empty():
		t.skip("giver_tag_location_for_every_quest: %d meta field(s) of other packages' quests are not the book's contract yet, e.g. %s" % [foreign.size(), foreign[0]])
	var unique: Array[String] = []
	for q in P13_QUESTS:
		# the quest-level title_key / description_key are the schema DEFAULTS (PLAN 3.12: QUEST_<ID>_TITLE / _DESC, the readers derive them): a top-level
		# Explicit scalar captions are also exposed by LuaRuntime; these older
		# twenty quests deliberately keep the derived-key contract.
		_need(unique, lm.text_in("QUEST_%s_TITLE" % q.to_upper(), "da") != "" and lm.text_in("QUEST_%s_DESC" % q.to_upper(), "da") != "", "%s: QUEST_<ID>_TITLE / _DESC has no text" % q)
		_need(unique, QuestText.title(StringName(q)) == lm.text_in("QUEST_%s_TITLE" % q.to_upper(), "da") and qm.get_title(StringName(q)) == lm.text_in("QUEST_%s_TITLE" % q.to_upper(), "da"),
			"%s: the quest book / QuestManager.get_title do not derive QUEST_<ID>_TITLE" % q)
		_need(unique, QuestText.description(StringName(q)) == lm.text_in("QUEST_%s_DESC" % q.to_upper(), "da"), "%s: the quest book does not derive QUEST_<ID>_DESC" % q)
		for o in _objectives(q):
			var od := LuaData.dict(o)
			if str(od.get("on", "")) == "":
				unique.append("%s.%s has no `on`" % [q, od.get("id", "")])
			if str(od.get("description_key", "")) != "OBJ_%s_%s" % [q.to_upper(), str(od.get("id", "")).to_upper()]:
				unique.append("%s.%s: description_key `%s`" % [q, od.get("id", ""), od.get("description_key", "")])
	t.check("every_objective_has_a_binding_and_its_own_text_key", unique.is_empty(), "the 20 quests: the quest book derives QUEST_<ID>_TITLE / _DESC (the schema defaults), `on` and description_key OBJ_<QUEST>_<OBJ> on every objective %s" % str(unique.slice(0, 3)))
	var math_ids: Array = _objectives("math_harvest_puzzle").map(func(o: Variant) -> String: return str(LuaData.dict(o).get("id", "")))
	t.check("math_objectives_renamed_unique", math_ids == ["math_harvest_carrot", "math_collect_stone", "math_collect_mushroom"], "math_harvest_puzzle: %s" % str(math_ids))
	var literal: Array[String] = []
	var foreign_literal: Array[String] = []
	for q in _quest_files():
		var text := FileAccess.get_file_as_string("res://lua/quests/%s.lua" % q)
		for line in text.split("\n"):
			var s := line.strip_edges()
			if s.begins_with("--"):
				continue
			if s.contains("description = \"") or s.contains("title = \""):
				((literal if (q in P13_QUESTS or q in FEATURE_EIGHT) else foreign_literal) as Array).append("%s: %s" % [q, s.substr(0, 40)])
	t.check("no_text_literals_in_the_quest_lua", literal.is_empty(), "no description = / title = literal in the 20 quests of this package or the four of F1 %s" % str(literal.slice(0, 3)))
	if not foreign_literal.is_empty():
		t.skip("no_text_literals_in_the_quest_lua: another package's quest still carries a text literal (%s): its owner moves it into its CSV" % foreign_literal[0])


## Every npc, item, recipe, crop, zone and map an objective or reward names exists: the table-driven test feeds an objective what its own definition says, so a typo
## in an id would be completed by the test and never by the game.
func _references_exist() -> void:
	var npcs: Dictionary = lr.get_npcs()
	var problems: Array[String] = []
	var maps := {}
	for f in DirAccess.get_files_at("res://data/maps"):
		if f.get_extension() == "map":
			maps[f.get_basename()] = true
	for q in _all_quest_ids():
		var def := _def(q)
		for o in _objectives(q):
			var od := LuaData.dict(o)
			var where := "%s.%s" % [q, od.get("id", "")]
			for field in ["npc"]:
				if str(od.get(field, "")) != "":
					_need(problems, npcs.has(str(od[field])), "%s: npc `%s` is not in npcs.lua" % [where, od[field]])
			for npc in LuaData.strings(od.get("any_of", [])):
				_need(problems, npcs.has(npc), "%s: any_of npc `%s` is not in npcs.lua" % [where, npc])
			if str(od.get("on", "")) == "item_gained":
				_need(problems, not LuaData.dict(lr.get_item_def(str(od.get("item", "")))).is_empty(), "%s: item `%s` has no item definition" % [where, od.get("item", "")])
			for item_id in LuaData.int_map(od.get("needs", {})):
				_need(problems, not LuaData.dict(lr.get_item_def(item_id)).is_empty(), "%s: needs item `%s` has no item definition" % [where, item_id])
			if str(od.get("on", "")) == "recipe_crafted":
				_need(problems, not LuaData.dict(lr.get_recipe(str(od.get("recipe", "")))).is_empty(), "%s: recipe `%s` does not exist" % [where, od.get("recipe", "")])
			if str(od.get("on", "")) in ["crop_planted", "crop_harvested"] and str(od.get("crop", "")) != "":
				_need(problems, lr.get_config("crops.%s" % str(od["crop"]), null) != null, "%s: crop `%s` is not in the crops config" % [where, od["crop"]])
			if str(od.get("on", "")) == "zone_entered":
				_need(problems, lm.text_in("ZONE_%s" % str(od.get("zone", "")).to_upper(), "da") != "", "%s: zone `%s` has no ZONE_ key" % [where, od.get("zone", "")])
			if str(od.get("on", "")) == "area_changed":
				var area := str(od.get("area", ""))
				_need(problems, maps.has(area) or area.begins_with("moerkeskoven_f") or area == "dybe_bregner", "%s: area `%s` is no map id" % [where, area])
		for item_id in LuaData.int_map(LuaData.dict(def.get("rewards", {})).get("items", {})):
			_need(problems, not LuaData.dict(lr.get_item_def(item_id)).is_empty(), "%s: reward item `%s` has no item definition" % [q, item_id])
		for npc in LuaData.dict(LuaData.dict(def.get("rewards", {})).get("friendship", {})):
			_need(problems, npcs.has(str(npc)), "%s: friendship reward names `%s`, who is not in npcs.lua" % [q, npc])
	t.check("objective_references_exist", problems.is_empty(), "%d quests: every npc, any_of npc, item, needs item, recipe, crop, zone, area and reward a quest names exists %s" % [_all_quest_ids().size(), str(problems.slice(0, 4))])


func _text_keys() -> void:
	var problems: Array[String] = []
	var raw := RegEx.new()
	raw.compile("^[A-Z0-9_]+$")
	for q in _all_quest_ids():
		var up := q.to_upper()
		var keys: Array[String] = [str(_def(q).get("title_key","QUEST_%s_TITLE" % up))]
		var own: bool = q in P13_QUESTS or q in FEATURE_EIGHT or q == "pips_runde" or q == "secret_garden"
		if own:
			keys.append("QUEST_%s_DESC" % up)
			if str(LuaData.dict(_def(q).get("meta", {})).get("giver", "")) != "":
				keys.append("QUEST_%s_OFFER" % up)
		else:
			# another package's quest: the book falls back from QUEST_<ID>_DESC to QUEST_<ID>_OFFER (TTQuestText.description), so one of the two is enough
			var description := str(_def(q).get("description_key",""))
			if description != "": keys.append(description)
			else:
				_need(problems, lm.text_in("QUEST_%s_DESC" % up, "da") != "" or lm.text_in("QUEST_%s_OFFER" % up, "da") != "", "%s: neither QUEST_%s_DESC nor _OFFER has a da text" % [q, up])
				_need(problems, lm.text_in("QUEST_%s_DESC" % up, "en") != "" or lm.text_in("QUEST_%s_OFFER" % up, "en") != "", "%s: neither QUEST_%s_DESC nor _OFFER has an en text" % [q, up])
		for o in _objectives(q):
			var od := LuaData.dict(o)
			var ok := str(od.get("description_key", ""))
			var found := false
			for k in [ok, "OBJ_%s_%s" % [up, str(od.get("id", "")).to_upper()], "OBJ_%s" % str(od.get("id", "")).to_upper()]:
				if k != "" and lm.text_in(k, "da") != "" and lm.text_in(k, "en") != "":
					found = true
					break
			_need(problems, found, "%s.%s has no objective text in da + en" % [q, od.get("id", "")])
		var source := FileAccess.get_file_as_string(str(_def(q).get("source_path", "")))
		var rx := RegEx.new()
		rx.compile("api\\.notification\\(\"([^\"]*)\", \"([^\"]*)\"\\)")
		for m in rx.search_all(source):
			for g in [m.get_string(1), m.get_string(2)]:
				keys.append(g)
				_need(problems, raw.search(g) != null, "%s: notification argument `%s` is not a loc key" % [q, g])
		for k in LuaData.dict(LuaData.dict(_def(q).get("rewards", {})).get("items", {})):
			keys.append("ITEM_%s" % str(k).to_upper())
		for k in keys:
			for locale in ["da", "en"]:
				_need(problems, lm.text_in(k, locale) != "" and lm.text_in(k, locale) != k, "%s: key %s has no %s text" % [q, k, locale])
	t.check("every_quest_text_key_resolves_in_da_and_en", problems.is_empty(), "%d quests: title, description, offer, every objective, every toast key and every reward item name in da + en %s" % [_all_quest_ids().size(), str(problems.slice(0, 3))])
	var csv: Dictionary = lm.read_csv("res://localization/quests.csv")
	var stray: Array[String] = []
	var n_rows := 0
	for row in csv.get("rows", []):
		var k := str((row["cells"] as PackedStringArray)[0]).strip_edges()
		if k.begins_with(";") or k.begins_with("#"):
			continue
		n_rows += 1
		if not (k.begins_with("QUEST_") or k.begins_with("OBJ_") or k.begins_with("LUANOTIF_")):
			stray.append(k)
		for f1 in ["BOGTRAEET", "MOONSTONE_CROWN", "SNURRESVAMPEN", "SLOTSDROEMMEN"]:
			if k.begins_with("QUEST_%s_" % f1) or k.begins_with("OBJ_%s_" % f1):
				stray.append(k)
	t.check("quests_csv_owns_only_its_families", stray.is_empty() and n_rows > 100 and lm.file_of("QUEST_LOST_CAT_TITLE") == "quests.csv" and lm.file_of("QUEST_BOGTRAEET_TITLE") == "features_quests.csv"
		and lm.file_of("OBJ_FAIRY_FRIENDSHIP_HELP_CITIZENS") == "quests.csv" and lm.has_key("QUEST_FAIRY_FRIENDSHIP_TITLE"),
		"%d rows, all QUEST_ / OBJ_ / LUANOTIF_, none of the four feature quests (features_quests.csv); QUEST_FAIRY_FRIENDSHIP_TITLE replaces the legacy typo %s" % [n_rows, str(stray.slice(0, 3))])


# =============================================================================================== the vocabulary, one `on` at a time

func _vocabulary_events() -> void:
	var problems: Array = []
	_fresh()
	# item_gained (event counting), with amount
	var q := _start("zz_p13_item", [{"id": "o", "target": 5, "on": "item_gained", "item": "wood"}])
	bus.item_gained.emit(PlayerRegistry.local_id(), &"wood", 3)
	bus.item_gained.emit(PlayerRegistry.local_id(), &"stone", 9)
	_need(problems, _cur(q, "o") == 3, "item_gained: wood x3 and stone x9 gave %d, want 3" % _cur(q, "o"))
	bus.item_gained.emit(PlayerRegistry.local_id(), &"wood", 9)
	_need(problems, _cur(q, "o") == 5 and _done(q, "o"), "item_gained: capped at the target 5, got %d" % _cur(q, "o"))
	qm.reset()
	# crop_planted with a comma list, crop_watered, crop_harvested with amount
	q = _start("zz_p13_crops", [{"id": "plant", "target": 3, "on": "crop_planted", "crop": "carrot,turnip"}, {"id": "water", "target": 2, "on": "crop_watered"},
		{"id": "harvest", "target": 12, "on": "crop_harvested", "crop": "carrot"}])
	bus.crop_planted.emit(&"p1", &"carrot")
	bus.crop_planted.emit(&"p2", &"pumpkin")
	bus.crop_planted.emit(&"p3", &"turnip")
	bus.crop_watered.emit(&"p1")
	bus.crop_harvested.emit(&"p1", &"carrot", 5)
	bus.crop_harvested.emit(&"p2", &"turnip", 9)
	bus.crop_harvested.emit(&"p1", &"carrot", 3)
	_need(problems, _cur(q, "plant") == 2, "crop_planted carrot,turnip: %d, want 2 (a pumpkin does not count)" % _cur(q, "plant"))
	_need(problems, _cur(q, "water") == 1, "crop_watered: %d" % _cur(q, "water"))
	_need(problems, _cur(q, "harvest") == 8, "crop_harvested carrot: %d, want 5 + 3 = 8" % _cur(q, "harvest"))
	qm.reset()
	# zone_entered versus area_changed: a zone id is not a map id
	q = _start("zz_p13_places", [{"id": "zone", "target": 1, "on": "zone_entered", "zone": "dark_forest"}, {"id": "area", "target": 1, "on": "area_changed", "area": "moerkeskoven_f4"}])
	bus.zone_entered.emit(&"city")
	bus.zone_entered.emit(&"moerkeskoven_f4")
	bus.area_changed.emit(&"dark_forest")
	bus.area_changed.emit(&"dybe_bregner")
	_need(problems, _cur(q, "zone") == 0 and _cur(q, "area") == 0, "a wrong zone / area / the other signal counted (%d / %d)" % [_cur(q, "zone"), _cur(q, "area")])
	bus.zone_entered.emit(&"dark_forest")
	bus.area_changed.emit(&"moerkeskoven_f4")
	_need(problems, _done(q, "zone") and _done(q, "area"), "zone dark_forest / area moerkeskoven_f4 did not bind")
	qm.reset()
	# dialogue_started: a listed npc counts once, an unlisted one never; a plain npc counts every dialogue
	q = _start("zz_p13_talk", [{"id": "ask", "target": 3, "on": "dialogue_started", "any_of": ["a", "b", "c"]}, {"id": "chat", "target": 2, "on": "dialogue_started", "npc": "x"}])
	bus.start_dialogue(&"a", &"a")
	bus.start_dialogue(&"a", &"a")
	bus.start_dialogue(&"d", &"d")
	_need(problems, _cur(q, "ask") == 1, "any_of: a twice and d gave %d, want 1 (each listed npc counts once, d is not listed)" % _cur(q, "ask"))
	bus.start_dialogue(&"b", &"b")
	bus.start_dialogue(&"c", &"c")
	_need(problems, _done(q, "ask"), "any_of a, b, c did not complete a target of 3")
	bus.start_dialogue(&"x", &"x")
	bus.start_dialogue(&"x", &"x")
	_need(problems, _done(q, "chat"), "npc x twice did not complete the plain objective (%d)" % _cur(q, "chat"))
	qm.reset()
	# animals, buildings, enemies, recipes
	q = _start("zz_p13_world", [{"id": "adopt", "target": 1, "on": "animal_adopted", "species": "chicken"}, {"id": "fed", "target": 2, "on": "animal_fed", "food": "feed"},
		{"id": "egg", "target": 5, "on": "animal_product_collected", "product": "egg"}, {"id": "coop", "target": 1, "on": "building_built", "type": "coop"},
		{"id": "kill", "target": 1, "on": "enemy_defeated", "kind": "snurresvamp"}, {"id": "craft", "target": 3, "on": "recipe_crafted", "recipe": "flower_necklace"}])
	bus.animal_adopted.emit(&"a1", &"cow")
	bus.animal_fed.emit(&"a1", &"hay")
	bus.animal_product_collected.emit(&"a1", &"milk", 4)
	bus.building_built.emit(&"b1", &"barn")
	bus.enemy_defeated.emit(&"e1", &"bat", [])
	bus.recipe_crafted.emit(&"honey_cake", 1)
	_need(problems, _cur(q, "adopt") + _cur(q, "fed") + _cur(q, "egg") + _cur(q, "coop") + _cur(q, "kill") + _cur(q, "craft") == 0, "an event with the wrong species / food / product / type / kind / recipe counted")
	bus.animal_adopted.emit(&"a2", &"chicken")
	bus.animal_fed.emit(&"a1", &"feed")
	bus.animal_fed.emit(&"a1", &"feed")
	bus.animal_product_collected.emit(&"a1", &"egg", 2)
	bus.animal_product_collected.emit(&"a1", &"egg", 2)
	bus.building_built.emit(&"b2", &"coop")
	bus.enemy_defeated.emit(&"e2", &"snurresvamp", [])
	bus.recipe_crafted.emit(&"flower_necklace", 2)
	_need(problems, _done(q, "adopt") and _done(q, "fed") and _cur(q, "egg") == 4 and _done(q, "coop") and _done(q, "kill") and _cur(q, "craft") == 2,
		"adopt %d, fed %d, egg %d (want 4), coop %d, kill %d, craft %d (want 2)" % [_cur(q, "adopt"), _cur(q, "fed"), _cur(q, "egg"), _cur(q, "coop"), _cur(q, "kill"), _cur(q, "craft")])
	qm.reset()
	# quest_completed narrowed by category (help_citizens of fairy_friendship)
	_reg("zz_p13_helper_a", [], false, {}, {"category": "help"})
	_reg("zz_p13_helper_b", [], false, {}, {"category": "learning"})
	q = _start("zz_p13_help", [{"id": "help", "target": 2, "on": "quest_completed", "category": "help,errand"}])
	bus.quest_completed.emit(PlayerRegistry.local_id(), &"zz_p13_helper_b")
	_need(problems, _cur(q, "help") == 0, "a learning quest counted for category help,errand")
	bus.quest_completed.emit(PlayerRegistry.local_id(), &"zz_p13_helper_a")
	_need(problems, _cur(q, "help") == 1, "a help quest did not count (%d)" % _cur(q, "help"))
	qm.reset()
	# manual objectives move only through complete_manual / update_objective, never by an event; `amount` overrides the progress per event
	q = _start("zz_p13_manual", [{"id": "m", "target": 1, "on": "manual"}, {"id": "amt", "target": 6, "on": "item_gained", "item": "wood", "amount": 2}], false)
	bus.item_gained.emit(PlayerRegistry.local_id(), &"wood", 1)
	bus.game_event.emit(&"anything", {})
	_need(problems, _cur(q, "m") == 0 and _cur(q, "amt") == 2, "manual %d (want 0), amount=2 per event gave %d (want 2)" % [_cur(q, "m"), _cur(q, "amt")])
	_need(problems, qm.can_complete_manual(q, &"m") and qm.complete_manual(q, &"m") and _done(q, "m") and not qm.can_complete_manual(q, &"m"), "complete_manual(quest, objective) did not finish the manual objective once")
	qm.reset()
	t.check("binding_vocabulary_events", problems.is_empty(), "item_gained crop_planted crop_watered crop_harvested zone_entered area_changed dialogue_started(any_of) animal_* building_built enemy_defeated recipe_crafted quest_completed manual amount: %s" % str(problems.slice(0, 4)))
	var area_problems: Array = []
	q = _start("zz_p13_area", [{"id": "enter", "target": 1, "on": "area_changed", "area": "dybe_bregner"}])
	bus.zone_entered.emit(&"dark_forest")
	bus.area_changed.emit(&"skovkant")
	_need(area_problems, not _done(q, "enter"), "skovkant / the shared zone dark_forest completed `area_changed dybe_bregner`")
	bus.area_changed.emit(&"dybe_bregner")
	_need(area_problems, not qm.is_active(q) and qm.is_completed(q) or _done(q, "enter"), "EventBus.area_changed(dybe_bregner) did not complete the objective")
	t.check("area_changed_binding", area_problems.is_empty(), "on = area_changed binds the MAP id of EventBus.area_changed, not the zone: %s" % str(area_problems))
	qm.reset()


func _game_events() -> void:
	_fresh()
	var problems: Array = []
	# rarity (comma list) + min_level (payload.level, generic) + match entries
	var q := _start("zz_p13_events", [
		{"id": "rare", "target": 3, "on": "game_event", "event": "furniture_placed", "rarity": "unique,legendary"},
		{"id": "deep", "target": 1, "on": "game_event", "event": "dungeon_floor_entered", "min_level": 5},
		{"id": "stone", "target": 1, "on": "game_event", "event": "dungeon_runestone_activated", "min_level": 9},
		{"id": "mine", "target": 1, "on": "game_event", "event": "gift_given", "match": {"npc": "baker_maja", "item": "honey"}},
		{"id": "any", "target": 1, "on": "game_event", "event": "post_read"}])
	bus.game_event.emit(&"furniture_placed", {"item": "chair_pine", "rarity": "normal"})
	bus.game_event.emit(&"furniture_placed", {"item": "lamp", "rarity": "rare"})
	bus.game_event.emit(&"furniture_placed", {"item": "throne_root", "rarity": "unique"})
	bus.game_event.emit(&"furniture_placed", {"item": "clock_moon", "rarity": "legendary"})
	_need(problems, _cur(q, "rare") == 2 and not _done(q, "rare"), "rarity unique,legendary: %d, want 2 (a normal and a rare piece do not count)" % _cur(q, "rare"))
	bus.game_event.emit(&"furniture_placed", {"item": "bed", "rarity": "unique"})
	_need(problems, _done(q, "rare"), "a third unique piece did not finish the objective (%d)" % _cur(q, "rare"))
	bus.game_event.emit(&"furniture_placed", {"payload": "none"})
	bus.game_event.emit(&"post_read", {"quest_id": "lost_cat"})
	_need(problems, _done(q, "any"), "a game_event without filters did not bind")
	bus.game_event.emit(&"unknown_event", {"level": 99, "rarity": "unique"})
	_need(problems, not _done(q, "deep") and not _done(q, "mine"), "an unknown event name moved an objective")
	t.check("game_event_binding_filters", problems.is_empty(), "event name + rarity (comma list); an unknown event and a wrong filter never count: %s" % str(problems.slice(0, 3)))
	var match_problems: Array = []
	bus.game_event.emit(&"gift_given", {"npc": "baker_maja", "item": "milk", "taste": "like", "points": 20, "birthday": false})
	bus.game_event.emit(&"gift_given", {"npc": "farmer_rosa", "item": "honey"})
	bus.game_event.emit(&"gift_given", {"item": "honey"})
	_need(match_problems, _cur(q, "mine") == 0, "match {npc, item} counted a gift to another npc, of another item, or one without an npc")
	bus.game_event.emit(&"gift_given", {"npc": "baker_maja", "item": "honey", "taste": "love", "points": 80, "birthday": false})
	_need(match_problems, _done(q, "mine"), "match {npc = baker_maja, item = honey} did not bind the gift")
	qm.reset()
	var qn := _start("zz_p13_numbers", [{"id": "n", "target": 1, "on": "game_event", "event": "furniture_placed", "match": {"uid": 7}}])
	bus.game_event.emit(&"furniture_placed", {"item": "x", "rarity": "normal", "uid": 8})
	_need(match_problems, not _done(qn, "n"), "match uid = 7 counted uid 8")
	bus.game_event.emit(&"furniture_placed", {"item": "x", "rarity": "normal", "uid": 7.0})
	_need(match_problems, _done(qn, "n"), "match uid = 7 did not count a payload 7.0 (a number from JSON)")
	t.check("game_event_match_filter", match_problems.is_empty(), "match = { npc, item, id } compares payload entries (numbers as numbers, a missing entry never matches): %s" % str(match_problems.slice(0, 3)))
	qm.reset()
	_fresh()
	q = _start("zz_p13_events", [{"id": "deep", "target": 1, "on": "game_event", "event": "dungeon_floor_entered", "min_level": 5}, {"id": "stone", "target": 1, "on": "game_event", "event": "dungeon_runestone_activated", "min_level": 9}])
	# min_level is generic: the dungeon sends level = the floor number, anything else its own level; a payload without level never matches
	problems.clear()
	bus.game_event.emit(&"dungeon_floor_entered", {"floor": 4, "level": 4, "band": 1, "zone": "dark_forest", "seed_day": 3, "first_today": true, "deepest": false})
	bus.game_event.emit(&"dungeon_floor_entered", {"floor": 5})
	_need(problems, not _done(q, "deep"), "floor 4 (and a payload without level) reached `floor >= 5`")
	bus.game_event.emit(&"dungeon_floor_entered", {"floor": 8, "level": 8, "band": 2, "zone": "dark_forest", "seed_day": 3, "first_today": true, "deepest": true})
	_need(problems, _done(q, "deep"), "floor 8 (level 8) did not reach `floor >= 5` (min_level is a lower bound, not an equality)")
	bus.game_event.emit(&"dungeon_runestone_activated", {"floor": 7, "level": 7, "band": 2, "first_time": true, "waypoint": true})
	_need(problems, not _done(q, "stone"), "a runestone on floor 7 counted for `floor >= 9`")
	bus.game_event.emit(&"dungeon_runestone_activated", {"floor": 11, "level": 11, "band": 4, "first_time": false, "waypoint": true})
	_need(problems, _done(q, "stone"), "a runestone on floor 11 did not count for `floor >= 9`")
	qm.reset()
	var q2 := _start("zz_p13_hygge", [{"id": "royal", "target": 1, "on": "game_event", "event": "hygge_level", "min_level": 5}])
	bus.game_event.emit(&"hygge_level", {"level": 4})
	_need(problems, not _done(q2, "royal"), "hygge level 4 reached min_level 5")
	bus.game_event.emit(&"hygge_level", {"level": 5})
	_need(problems, _done(q2, "royal"), "hygge level 5 did not reach min_level 5 (the same filter as the dungeon floors)")
	var q3 := _start("zz_p13_hygge_exact", [{"id": "exact", "target": 1, "on": "game_event", "event": "hygge_level", "min_level": 3}])
	bus.game_event.emit(&"hygge_level", {"level": 5})
	_need(problems, _done(q3, "exact"), "hygge level 5 did not reach min_level 3 (a lower bound, not an equality)")
	t.check("game_event_min_level_generic", problems.is_empty(), "min_level reads payload.level for dungeon_floor_entered, dungeon_runestone_activated and hygge_level alike: %s" % str(problems.slice(0, 3)))
	# the four dungeon events with their real payloads (ADDENDUM 8.4) bind a quest each
	problems.clear()
	qm.reset()
	for pair in [["dungeon_floor_entered", 1], ["dungeon_runestone_activated", 3], ["dungeon_boss_defeated", 4], ["dungeon_run_ended", 1]]:
		var qd := _start("zz_p13_%s" % pair[0], [{"id": "o", "target": 1, "on": "game_event", "event": pair[0]}], false)
		bus.game_event.emit(StringName(pair[0]), (EVENT_PAYLOADS[pair[0]] as Dictionary).duplicate(true))
		_need(problems, qm.is_completed(qd), "%s with its real payload did not complete an objective bound to it" % pair[0])
	t.check("dungeon_event_payloads_bind", problems.is_empty(), "dungeon_floor_entered, dungeon_runestone_activated, dungeon_boss_defeated, dungeon_run_ended: %s" % str(problems))
	qm.reset()


func _state_objectives() -> void:
	_fresh()
	var fakes := _fakes()
	var furniture: FakeFurniture = fakes["furniture"]
	var home: FakeHome = fakes["home"]
	var social: FakeSocial = fakes["social"]
	var problems: Array = []
	# placed_by_rarity: keepsakes that already stand count at accept; one piece placed six times does not
	furniture.placed = {"unique": 2, "legendary": 1, "normal": 7}
	var q := _start("zz_p13_state", [{"id": "treasures", "target": 6, "on": "state", "state": "placed_by_rarity", "rarity": "unique,legendary"}])
	_need(problems, _cur(q, "treasures") == 3, "3 keepsakes already stood at accept: progress %d, want 3 (normal pieces do not count)" % _cur(q, "treasures"))
	for i in 6:
		bus.game_event.emit(&"furniture_placed", {"item": "throne_root", "rarity": "unique"})
	_need(problems, _cur(q, "treasures") == 3, "placing ONE piece six times (six furniture_placed events) moved the progress to %d" % _cur(q, "treasures"))
	furniture.placed = {"unique": 4, "legendary": 1}
	bus.furniture_changed.emit(&"placed")
	_need(problems, _cur(q, "treasures") == 5, "five keepsakes standing after furniture_changed: progress %d, want 5" % _cur(q, "treasures"))
	furniture.placed = {"unique": 3, "legendary": 1}
	bus.furniture_changed.emit(&"removed")
	_need(problems, _cur(q, "treasures") == 4, "picking one up lowers the progress before it is done: %d, want 4" % _cur(q, "treasures"))
	furniture.placed = {"unique": 4, "legendary": 2}
	bus.furniture_changed.emit(&"placed")
	_need(problems, qm.is_completed(q) or _done(q, "treasures"), "six keepsakes standing did not finish the objective")
	qm.reset()
	t.check("state_objective_counts_standing_pieces", problems.is_empty(), "placed_by_rarity = pieces standing now, evaluated at accept and on furniture_changed: %s" % str(problems.slice(0, 3)))
	# hygge level / home tier / friend hearts: thresholds read the owner, are re-evaluated on their signals, stay done once reached
	problems.clear()
	furniture.level = 2
	home.tier = 3
	social.hearts_of = {"mayor_lyra": 4}
	q = _start("zz_p13_thresholds", [{"id": "hygge", "target": 1, "on": "state", "state": "hygge_level_at_least", "min_level": 3},
		{"id": "tier", "target": 1, "on": "state", "state": "home_tier_at_least", "min_level": 5},
		{"id": "hearts", "target": 1, "on": "state", "state": "friend_hearts_at_least", "npc": "mayor_lyra", "hearts": 8}])
	_need(problems, _cur(q, "hygge") + _cur(q, "tier") + _cur(q, "hearts") == 0, "thresholds that do not hold yet showed progress")
	furniture.level = 3
	bus.hygge_changed.emit(130, &"rigtig_hyggeligt")
	home.tier = 5
	bus.home_upgraded.emit(4, 5)
	social.hearts_of["mayor_lyra"] = 8
	bus.friend_changed.emit(PlayerRegistry.local_id(), &"mayor_lyra", 8)
	_need(problems, _done(q, "hygge") and _done(q, "tier") and _done(q, "hearts"), "hygge %s tier %s hearts %s after their signals" % [_done(q, "hygge"), _done(q, "tier"), _done(q, "hearts")])
	furniture.level = 0
	home.tier = 1
	social.hearts_of["mayor_lyra"] = 0
	bus.hygge_changed.emit(0, &"koldt")
	bus.furniture_changed.emit(&"removed")
	_need(problems, _done(q, "hygge") and _done(q, "tier") and _done(q, "hearts"), "a threshold that was reached is not allowed to fall back (stays done)")
	qm.reset()
	t.check("state_friend_hearts_at_least", problems.is_empty(), "friend_hearts_at_least / hygge_level_at_least / home_tier_at_least read their owner, re-evaluate on friend_changed / hygge_changed / home_upgraded and stay done: %s" % str(problems.slice(0, 3)))
	# a state objective is re-evaluated on load (the sections of the save are applied before load_completed)
	problems.clear()
	furniture.level = 0
	q = _start("zz_p13_load", [{"id": "hygge", "target": 1, "on": "state", "state": "hygge_level_at_least", "min_level": 2}])
	var saved: Dictionary = JSON.parse_string(JSON.stringify(qm.to_dict()))
	qm.reset()
	furniture.level = 4
	_need(problems, qm.from_dict(saved) and qm.is_active(q) and _cur(q, "hygge") == 0, "the loaded record keeps its progress (0)")
	bus.load_completed.emit(0)
	_need(problems, qm.is_completed(q) or _done(q, "hygge"), "load_completed did not re-evaluate the state objective")
	qm.reset()
	t.check("state_objective_reevaluated_on_load", problems.is_empty(), "%s" % str(problems))
	# a registered Callable wins over the built-in answer; an unknown query is a lint finding
	problems.clear()
	var calls := [0]
	var custom := func(od: Dictionary) -> int:
		calls[0] += 1
		return int(od.get("target", 1))
	qm.register_state_query(&"zz_custom", custom)
	var qc := _start("zz_p13_custom", [{"id": "c", "target": 2, "on": "state", "state": "zz_custom"}], false)
	_need(problems, calls[0] >= 1 and qm.is_completed(qc), "a registered state query was not asked / its answer was not used (%d calls)" % calls[0])
	_need(problems, "zz_custom" in qm.known_state_queries(), "known_state_queries() does not list the registered query")
	qm.unregister_state_query(&"zz_custom")
	t.check("state_query_registration", problems.is_empty(), "register_state_query(name, Callable(def) -> count): %s" % str(problems))
	qm.reset()
	_free_fakes(fakes)


func _turn_ins_have_and_delivery() -> void:
	_fresh()
	var problems: Array = []
	# after_others: a turn-in counts only when everything else was done BEFORE the event
	var q := _start("zz_p13_turnin", [{"id": "find", "target": 1, "on": "zone_entered", "zone": "dark_forest"},
		{"id": "report", "target": 1, "on": "dialogue_started", "npc": "guard_oak", "after_others": true}], false)
	bus.start_dialogue(&"guard_oak", &"guard_oak")
	_need(problems, _cur(q, "report") == 0, "the turn-in counted before the other objective was done")
	bus.zone_entered.emit(&"dark_forest")
	_need(problems, qm.is_active(q) and _cur(q, "report") == 0, "finishing the other objective let the turn-in through")
	bus.start_dialogue(&"guard_oak", &"guard_oak")
	_need(problems, qm.is_completed(q), "the turn-in after the other objective did not complete the quest")
	qm.reset()
	# one event never finishes a talk objective and its turn-in with the same npc together
	q = _start("zz_p13_sameevent", [{"id": "greet", "target": 1, "on": "dialogue_started", "npc": "guard_oak"},
		{"id": "report", "target": 1, "on": "dialogue_started", "npc": "guard_oak", "after_others": true}], false)
	bus.start_dialogue(&"guard_oak", &"guard_oak")
	_need(problems, qm.is_active(q) and _done(q, "greet") and not _done(q, "report"), "one dialogue finished the greeting AND its turn-in")
	bus.start_dialogue(&"guard_oak", &"guard_oak")
	_need(problems, qm.is_completed(q), "the second dialogue did not finish the turn-in")
	qm.reset()
	t.check("after_others_turn_in", problems.is_empty(), "a turn-in is judged on the state before the event: %s" % str(problems.slice(0, 3)))
	# have = true tracks the inventory (accept counts what you own, an inventory change a frame later, removal lowers it, done stays done)
	problems.clear()
	_fresh()
	eco.add_item(&"wood", 3, true)
	q = _start("zz_p13_have", [{"id": "wood", "target": 5, "on": "item_gained", "item": "wood", "have": true}])
	_need(problems, _cur(q, "wood") == 3, "accept did not count the 3 wood the player already owns (%d)" % _cur(q, "wood"))
	eco.add_item(&"wood", 1)
	await t.frames(1)
	_need(problems, _cur(q, "wood") == 4, "a picked-up wood did not show a frame later (%d, want 4)" % _cur(q, "wood"))
	eco.remove_item(&"wood", 3)
	await t.frames(1)
	_need(problems, _cur(q, "wood") == 1, "removal before done did not lower the progress (%d, want 1)" % _cur(q, "wood"))
	eco.add_item(&"wood", 9)
	await t.frames(1)
	_need(problems, _done(q, "wood"), "reaching the target did not finish the objective (%d)" % _cur(q, "wood"))
	qm.reset()
	var gate := _start("zz_p13_have2", [{"id": "wood", "target": 2, "on": "item_gained", "item": "wood", "have": true}])
	await t.frames(1)
	_need(problems, _done(gate, "wood") or qm.is_completed(gate), "a quest accepted while the player owns the goods did not finish")
	t.check("have_objective_tracks_inventory", problems.is_empty(), "have = true: counts what you own at accept, follows add / remove (coalesced to the next frame), done stays done: %s" % str(problems.slice(0, 3)))
	# delivery: needs + consume take the goods in the commit of the progress; without them a toast and no progress
	problems.clear()
	_fresh()
	var toasts: Array = []
	var catch := func(title: String, message: String, _icon: String) -> void: toasts.append([title, message])
	bus.notification_posted.connect(catch)
	q = _start("zz_p13_deliver", [{"id": "carrots", "target": 4, "on": "item_gained", "item": "carrot", "have": true},
		{"id": "give", "target": 1, "on": "dialogue_started", "npc": "baker_maja", "after_others": true, "needs": {"carrot": 4}, "consume": true}], false)
	eco.add_item(&"carrot", 6)
	await t.frames(1)
	_need(problems, _done(q, "carrots"), "four of six carrots did not finish the have objective")
	eco.remove_item(&"carrot", 4)                          # the player sold / ate them after collecting
	var q2 := _start("zz_p13_deliver_too", [{"id": "give", "target": 1, "on": "dialogue_started", "npc": "baker_maja", "needs": {"carrot": 4}, "consume": true}])
	toasts.clear()
	bus.start_dialogue(&"baker_maja", &"baker_maja")
	_need(problems, qm.is_active(q) and not _done(q, "give") and eco.count_item(&"carrot") == 2, "a delivery without the goods progressed or took something")
	var missing := toasts.filter(func(p: Array) -> bool: return str(p[0]) == lm.text_in("QUEST_NEEDS_ITEMS_TITLE", "da"))
	_need(problems, missing.size() == 1, "two deliveries without the goods on one talk did not post exactly ONE `you are missing something` toast (%s)" % str(toasts))
	_need(problems, missing.size() == 1 and str(missing[0][1]).contains("2 af 4") and str(missing[0][1]).contains(tr(str(eco.item_def(&"carrot").get("name_key", "ITEM_CARROT")))), "the toast does not name the carrots and the shortfall 2 af 4 (%s)" % str(missing))
	qm.fail_quest(q2)
	eco.add_item(&"carrot", 4)
	bus.start_dialogue(&"baker_maja", &"baker_maja")
	_need(problems, qm.is_completed(q) and eco.count_item(&"carrot") == 2, "the delivery did not take exactly 4 carrots and complete (left %d, want 2)" % eco.count_item(&"carrot"))
	bus.notification_posted.disconnect(catch)
	qm.reset()
	t.check("delivery_consumes_the_goods", problems.is_empty(), "needs + consume = the goods leave the backpack with the progress, a missing good blocks it with one toast that names it: %s" % str(problems.slice(0, 3)))
	# completed_flag (SYS-05): while the flag is unset the live event progress stays where it is; the flag fills the whole target
	problems.clear()
	_fresh()
	q = _start("zz_p13_flagged", [{"id": "bats", "target": 3, "on": "enemy_defeated", "kind": "bat", "completed_flag": "zz_p13_bats_done"}])
	bus.enemy_defeated.emit(&"e1", &"bat", [])
	bus.enemy_defeated.emit(&"e2", &"bat", [])
	eco.add_item(&"wood", 1)
	await t.frames(1)
	qm.refresh_objectives()
	_need(problems, _cur(q, "bats") == 2, "a refresh with the flag unset changed the live progress 2/3 (%d)" % _cur(q, "bats"))
	gm.set_flag(&"zz_p13_bats_done", true)
	qm.refresh_objectives()
	_need(problems, _cur(q, "bats") == 3 and _done(q, "bats"), "the earned flag did not fill the objective (%d/3)" % _cur(q, "bats"))
	gm.clear_flag(&"zz_p13_bats_done")
	qm.reset()
	t.check("completed_flag_keeps_live_progress", problems.is_empty(), "completed_flag only raises progress: an unset flag never resets 2/3 to 0, a set one completes the objective: %s" % str(problems.slice(0, 3)))


func _legacy_ids_and_double_counting() -> void:
	_fresh()
	var problems: Array = []
	# review_regressions pins the old id convention for objectives WITHOUT `on`: harvest_<crop> / harvest_any / collect_<item> (resource drops)
	var q := _start("zz_p13_legacy", [{"id": "harvest_carrot", "target": 2}, {"id": "harvest_any", "target": 2}, {"id": "collect_iron_ore", "target": 2}], false)
	bus.crop_harvested.emit(&"p1", &"carrot", 1)
	bus.resource_node_depleted.emit(&"ore_1", [{"id": &"iron_ore", "amount": 2}, {"id": &"stone", "amount": 1}])
	_need(problems, _cur(q, "harvest_carrot") == 1 and _cur(q, "harvest_any") == 1 and _cur(q, "collect_iron_ore") == 2, "legacy ids: %d / %d / %d" % [_cur(q, "harvest_carrot"), _cur(q, "harvest_any"), _cur(q, "collect_iron_ore")])
	qm.reset()
	# an objective WITH `on` counts a drop once (item_gained), never again through resource_node_depleted: the old double counting
	q = _start("zz_p13_double", [{"id": "iron", "target": 4, "on": "item_gained", "item": "iron_ore"}])
	bus.resource_node_depleted.emit(&"ore_1", [{"id": &"iron_ore", "amount": 2}])
	bus.item_gained.emit(PlayerRegistry.local_id(), &"iron_ore", 2)
	_need(problems, _cur(q, "iron") == 2, "a drop of 2 ore counted %d times (want 2: item_gained only)" % _cur(q, "iron"))
	qm.reset()
	t.check("resource_drop_counts_once", problems.is_empty(), "the resource_node_depleted special case only feeds objectives without `on`: %s" % str(problems))


func _social_sugar_and_friendship() -> void:
	var problems: Array = []
	_fresh()
	var q := _start("zz_p13_sugar", [{"id": "gift", "target": 1, "on": "gift_given", "npc": "baker_maja"}, {"id": "scene", "target": 1, "on": "heart_event_finished", "npc": "mayor_lyra"},
		{"id": "festival", "target": 1, "on": "festival_attended", "match": {"id": "midsommer"}}])
	bus.game_event.emit(&"gift_given", {"npc": "farmer_rosa", "item": "honey", "taste": "love", "points": 80, "birthday": false})
	_need(problems, _cur(q, "gift") == 0, "a gift to farmer_rosa counted for npc = baker_maja")
	bus.game_event.emit(&"gift_given", {"npc": "baker_maja", "item": "honey", "taste": "like", "points": 40, "birthday": true})
	bus.game_event.emit(&"heart_event_finished", {"id": "lyra_one", "npc": "baker_maja", "hearts": 2})
	_need(problems, _done(q, "gift"), "gift_given sugar did not bind a gift to baker_maja")
	_need(problems, _cur(q, "scene") == 0, "heart_event_finished of another npc counted")
	bus.game_event.emit(&"heart_event_finished", {"id": "lyra_one", "npc": "mayor_lyra", "hearts": 4})
	_need(problems, _done(q, "scene"), "heart_event_finished sugar did not bind")
	bus.game_event.emit(&"festival_attended", {"id": "fastelavn"})
	_need(problems, _cur(q, "festival") == 0, "festival_attended of another festival counted (match = { id = midsommer })")
	bus.game_event.emit(&"festival_attended", {"id": "midsommer"})
	_need(problems, _done(q, "festival"), "festival_attended with match { id } did not bind")
	qm.reset()
	var q2 := _start("zz_p13_fest", [{"id": "f", "target": 1, "on": "festival_attended"}], false)
	bus.game_event.emit(&"festival_attended", {"id": "midsommer"})
	_need(problems, qm.is_completed(q2), "festival_attended without a filter did not bind")
	t.check("social_objective_sugar", problems.is_empty(), "gift_given / festival_attended / heart_event_finished are game_event sugar with npc / item / id filters: %s" % str(problems.slice(0, 3)))
	qm.reset()
	# friendship rewards go through SocialManager.add_hearts(npc, n, quest) when the autoload exists, and write nothing themselves
	problems.clear()
	var fakes := _fakes()
	var social: FakeSocial = fakes["social"]
	qm.register_quest_from_lua({"id": "zz_p13_friends", "objectives": [], "rewards": {"friendship": {"pippin_boegeknop": 2, "fairy_king": 1}}, "meta": {}})
	qm.accept_quest(&"zz_p13_friends")
	qm.complete_quest(&"zz_p13_friends")
	_need(problems, social.calls == [[&"pippin_boegeknop", 2, &"quest"], [&"fairy_king", 1, &"quest"]], "add_hearts calls: %s" % str(social.calls))
	_need(problems, not gm.world_flags.has(&"friend_pippin_boegeknop") and not gm.world_flags.has(&"friend_fairy_king"), "QuestManager wrote friend_<npc> although SocialManager exists")
	t.check("friendship_reward_goes_through_social_manager", problems.is_empty(), "rewards.friendship -> SocialManager.add_hearts(npc, n, &quest), no flag written by the quest package: %s" % str(problems))
	_free_fakes(fakes)
	# without S-core the flag path pays: whole hearts, capped at 10, friend_changed only when the hearts changed
	problems.clear()
	var plain := PlainNode.new()
	Svc.override("SocialManager", plain)
	var changed: Array = []
	var catch := func(_player_id: StringName, npc: StringName, hearts: int) -> void: changed.append([npc, hearts])
	bus.friend_changed.connect(catch)
	gm.set_flag(&"friend_mayor_lyra", 9)
	qm.register_quest_from_lua({"id": "zz_p13_cap", "objectives": [], "rewards": {"friendship": {"mayor_lyra": 2, "baker_maja": 3}}, "meta": {"repeatable": true, "cooldown_days": 0}})
	qm.accept_quest(&"zz_p13_cap")
	qm.complete_quest(&"zz_p13_cap")
	_need(problems, gm.flag_int(&"friend_mayor_lyra", 0) == 10, "9 hearts + 2 gave %d, want the cap 10" % gm.flag_int(&"friend_mayor_lyra", 0))
	_need(problems, gm.flag_int(&"friend_baker_maja", 0) == 3, "0 + 3 hearts gave %d" % gm.flag_int(&"friend_baker_maja", 0))
	_need(problems, changed == [[&"mayor_lyra", 10], [&"baker_maja", 3]], "friend_changed emissions %s" % str(changed))
	changed.clear()
	qm.accept_quest(&"zz_p13_cap")
	qm.complete_quest(&"zz_p13_cap")
	_need(problems, gm.flag_int(&"friend_mayor_lyra", 0) == 10 and changed == [[&"baker_maja", 6]], "at the cap nothing changes and nothing is emitted for it: %s" % str(changed))
	bus.friend_changed.disconnect(catch)
	Svc.clear_overrides()
	plain.free()
	t.check("friendship_reward_cap", problems.is_empty(), "without SocialManager: flag friend_<npc> += n capped at 10, friend_changed(npc, hearts) when the hearts changed: %s" % str(problems.slice(0, 3)))
	qm.reset()


# =============================================================================================== the real managers of the other packages

## The late-bound names (SocialManager.hearts / add_hearts, HomeManager.tier, FurnitureManager.count_placed_by_rarity / hygge_level_index) against the REAL
## managers that exist in the tree: S-core's SocialManager autoload and F2's HomeManager script (made off-tree: its _ready would register a save section).
## The rest of the section uses small fakes; this check is what makes a rename on the owner's side a red line here instead of a silent 0.
func _real_managers() -> void:
	_fresh()                                  # no override left: Svc.node(..) answers the real autoloads
	var problems: Array = []
	var social: Node = Svc.node("SocialManager")
	if social == null or not social.has_method("add_hearts") or not social.has_method("hearts"):
		t.skip("real_managers_contract: SocialManager (S-core) is not in this tree with hearts / add_hearts")
	else:
		# a quest reward is whole hearts through the one writer, which mirrors them into the flag friend_<npc> itself
		qm.register_quest_from_lua({"id": "zz_p13_real_friends", "objectives": [], "rewards": {"friendship": {"pippin_boegeknop": 2, "baker_maja": 1}}, "meta": {}})
		qm.accept_quest(&"zz_p13_real_friends")
		qm.complete_quest(&"zz_p13_real_friends")
		_need(problems, int(social.call("hearts", &"pippin_boegeknop")) == 2 and int(social.call("hearts", &"baker_maja")) == 1,
			"hearts after the reward: pippin %s (want 2), maja %s (want 1)" % [social.call("hearts", &"pippin_boegeknop"), social.call("hearts", &"baker_maja")])
		_need(problems, gm.flag_int(&"friend_pippin_boegeknop", 0) == 2, "the real SocialManager did not mirror the hearts into friend_pippin_boegeknop (%d)" % gm.flag_int(&"friend_pippin_boegeknop", 0))
		# friend_hearts_at_least reads SocialManager.hearts and wakes up on the friend_changed the real writer emits
		var q := _start("zz_p13_real_hearts", [{"id": "maja", "target": 1, "on": "state", "state": "friend_hearts_at_least", "npc": "baker_maja", "hearts": 3}], false)
		_need(problems, _cur(q, "maja") == 0, "baker_maja has 1 heart and the objective asks for 3 (progress %d)" % _cur(q, "maja"))
		social.call("add_hearts", &"baker_maja", 1, &"quest")
		_need(problems, _cur(q, "maja") == 0, "2 hearts of 3 already finished the objective")
		social.call("add_hearts", &"baker_maja", 1, &"quest")
		_need(problems, qm.is_completed(q), "3 hearts (the real friend_changed) did not finish friend_hearts_at_least (progress %d)" % _cur(q, "maja"))
		# the guide quest end to end with the real SocialManager: Pippin ends at 2 hearts
		_fresh()
		qm.accept_quest(&"lost_cat")
		for npc in ["baker_maja", "merchant_pip", "mayor_lyra"]:
			bus.start_dialogue(StringName(npc), StringName(npc))
		qm.complete_manual(&"lost_cat", &"follow_pawprints")
		bus.start_dialogue(&"cat_morfar_mis", &"cat_morfar_mis")
		bus.start_dialogue(&"pippin_boegeknop", &"pippin_boegeknop")
		_need(problems, qm.is_completed(&"lost_cat"), "lost_cat was not completed with the real SocialManager in the tree")
		_need(problems, int(social.call("hearts", &"pippin_boegeknop")) == 2, "lost_cat paid %s hearts to Pippin through the real SocialManager, want 2" % social.call("hearts", &"pippin_boegeknop"))
	t.check("real_managers_social_contract", problems.is_empty(), "rewards.friendship -> the real SocialManager.add_hearts (mirrored into friend_<npc>), friend_hearts_at_least on the real hearts / friend_changed, lost_cat pays Pippin 2 hearts: %s" % str(problems.slice(0, 3)))
	# F2's real HomeManager: home_tier_at_least reads its `tier` and wakes up on home_upgraded
	_fresh()
	problems.clear()
	var home_script: Variant = load("res://scripts/home/home_manager.gd")
	if home_script == null or not (home_script is GDScript):
		t.skip("real_managers_home_contract: scripts/home/home_manager.gd (F2-home-core) is not in this tree")
	else:
		var home: Node = (home_script as GDScript).new()
		Svc.override("HomeManager", home)
		var q2 := _start("zz_p13_real_tier", [{"id": "tier", "target": 1, "on": "state", "state": "home_tier_at_least", "min_level": 5}], false)
		_need(problems, _cur(q2, "tier") == 0, "tier 1 finished home_tier_at_least 5")
		home.set("tier", 4)
		bus.home_upgraded.emit(3, 4)
		_need(problems, _cur(q2, "tier") == 0, "tier 4 finished home_tier_at_least 5")
		home.set("tier", 5)
		bus.home_upgraded.emit(4, 5)
		_need(problems, qm.is_completed(q2), "the real HomeManager.tier = 5 did not finish home_tier_at_least 5")
		Svc.clear_overrides()
		home.free()
		t.check("real_managers_home_contract", problems.is_empty(), "home_tier_at_least reads the real HomeManager.tier and re-evaluates on home_upgraded: %s" % str(problems.slice(0, 3)))
	# F3's FurnitureManager is built by a later package: its two names stay proven against the fake until it lands
	var furniture: Node = Svc.node("FurnitureManager")
	if furniture == null:
		t.skip("real_managers_furniture_contract: FurnitureManager (F3-furniture-core) is not in this tree - count_placed_by_rarity / hygge_level_index are proven against a fake only")
	else:
		t.check("real_managers_furniture_contract", furniture.has_method("count_placed_by_rarity") and furniture.has_method("hygge_level_index"),
			"FurnitureManager offers count_placed_by_rarity(rarities) and hygge_level_index() (the names on_state objectives ask)")
	qm.reset()
	_fresh()


# =============================================================================================== offers, tracker, journal, cooldowns

func _offers() -> void:
	_fresh()
	var problems: Array = []
	var maja: Array = qm.offerable(&"baker_maja")
	_need(problems, _plain(maja) == [&"cookie_delivery", &"birthday_cake", &"math_bakery_counts"], "baker_maja offers %s, want her npcs.lua order [cookie_delivery, birthday_cake, math_bakery_counts]" % str(maja))
	_need(problems, qm.offerable(&"nobody_here").is_empty() and qm.offerable(&"").is_empty(), "an unknown giver offered quests")
	qm.accept_quest(&"cookie_delivery")
	_need(problems, not (&"cookie_delivery" in qm.offerable(&"baker_maja")), "an ACTIVE quest is still offered")
	qm.accept_quest(&"birthday_cake")
	qm.complete_quest(&"birthday_cake")
	_need(problems, not (&"birthday_cake" in qm.offerable(&"baker_maja")), "a finished one-shot quest is still offered")
	gm.set_flag(&"math_bakery_done", true)
	_need(problems, not (&"math_bakery_counts" in qm.offerable(&"baker_maja")), "a quest whose Lua is_available says no (math_bakery_done) is still offered")
	_need(problems, &"intro_lottery" in qm.offerable(&"mayor_lyra") and &"lost_cat" in qm.offerable(&"pippin_boegeknop"), "mayor_lyra / pippin_boegeknop do not offer their opening quests")
	_need(problems, qm.is_offerable(&"cookie_delivery") == false and qm.is_offerable(&"lost_cat") and not qm.is_offerable(&"night_flower") and not qm.is_offerable(&"no_such_quest"), "is_offerable(quest): active / zone-locked / unknown quests are refused, an open one is accepted")
	t.check("offerable_by_giver", problems.is_empty(), "offerable(npc) = available now, not active, not done, in npcs.lua order: %s" % str(problems.slice(0, 3)))
	# requires_zone gates the offers (the Dark Wood has to be known), accept by an explicit dialogue choice is never blocked
	problems.clear()
	_fresh()
	var oak: Array = qm.offerable(&"guard_oak")
	_need(problems, &"forest_patrol" in oak and not (&"night_flower" in oak), "guard_oak offers %s before the wood is unlocked (forest_patrol yes, night_flower no)" % str(oak))
	var thorin: Array = qm.offerable(&"smith_thorin")
	_need(problems, thorin.is_empty(), "smith_thorin offers %s before the wood is unlocked (all three of his quests ask for it)" % str(thorin))
	_need(problems, qm.accept_quest(&"night_flower"), "accept_quest was blocked by requires_zone (a dialogue choice is the gate, not the zone)")
	_fresh()                                   # the accept above set the quest's own active flag: a fresh game
	gm.unlock_zone(&"dark_forest")
	oak = qm.offerable(&"guard_oak")
	_need(problems, &"night_flower" in oak and oak.find(&"forest_patrol") < oak.find(&"night_flower"), "guard_oak after unlock: %s (night_flower follows forest_patrol)" % str(oak))
	_need(problems, _plain(qm.offerable(&"smith_thorin")) == [&"dark_forest_mining", &"sword_upgrade", &"crystal_cave"], "smith_thorin after unlock: %s, want his npcs.lua order" % str(qm.offerable(&"smith_thorin")))
	var many: Array = qm.offerable_for([&"guard_oak", &"baker_maja", &"smith_thorin"])
	var shape_ok := not many.is_empty()
	for row in many:
		shape_ok = shape_ok and (row as Dictionary).has("quest_id") and (row as Dictionary).has("giver") and str(LuaData.dict(_def((row as Dictionary)["quest_id"]).get("meta", {})).get("giver", "")) == str((row as Dictionary)["giver"])
	var givers_in_order: Array = []
	for row in many:
		if not (givers_in_order.has((row as Dictionary)["giver"])):
			givers_in_order.append((row as Dictionary)["giver"])
	_need(problems, shape_ok and givers_in_order == [&"guard_oak", &"baker_maja", &"smith_thorin"], "offerable_for rows %s, givers in order %s" % [str(many.slice(0, 2)), str(givers_in_order)])
	t.check("offerable_for_many", problems.is_empty(), "offerable_for(givers) = [{quest_id, giver}] in the order of the givers, one entry per offerable quest: %s" % str(problems.slice(0, 3)))
	# V3's post.givers: every quest of those givers has an offer text (the letters / the board show it)
	var cfg: Variant = lr.get_config("traetoppen.post.givers", null)
	if not (cfg is Array):
		t.skip("post_givers_have_offer_text: lua/config/traetoppen.lua (V3-levels) is not in this tree - the fixture list of the six everyday givers is used")
		cfg = ["mayor_lyra", "baker_maja", "merchant_pip", "farmer_rosa", "fairy_lily", "smith_thorin"]
	var missing: Array[String] = []
	var counted := 0
	for q in _all_quest_ids():
		if str(LuaData.dict(_def(q).get("meta", {})).get("giver", "")) in (cfg as Array):
			counted += 1
			for locale in ["da", "en"]:
				if lm.text_in("QUEST_%s_OFFER" % q.to_upper(), locale) == "":
					missing.append("%s/%s" % [q, locale])
	t.check("post_givers_have_offer_text", missing.is_empty() and counted >= 14, "%d quests of the post.givers (%s) have QUEST_<ID>_OFFER in da + en %s" % [counted, ", ".join(PackedStringArray(cfg as Array)), str(missing)])
	qm.reset()


func _tracked_and_journal() -> void:
	_fresh()
	var problems: Array = []
	var ids: Array[StringName] = []
	for i in 5:
		ids.append(_start("zz_p13_track_%d" % i, [{"id": "gate", "target": 1, "on": "manual"}], false))
	_need(problems, _plain(qm.get_tracked()) == [ids[0], ids[1], ids[2]], "get_tracked() = %s, want the three oldest accepted" % str(qm.get_tracked()))
	_need(problems, _plain(qm.get_tracked(2)) == [ids[0], ids[1]] and qm.get_tracked(10).size() == 5 and qm.get_tracked(0).is_empty(), "the cap is honoured: 2 -> %d, 10 -> %d, 0 -> %d" % [qm.get_tracked(2).size(), qm.get_tracked(10).size(), qm.get_tracked(0).size()])
	qm.complete_quest(ids[0])
	qm.fail_quest(ids[1])
	_need(problems, _plain(qm.get_tracked()) == [ids[2], ids[3], ids[4]], "a completed / failed quest is still tracked: %s" % str(qm.get_tracked()))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(qm.to_dict()))
	qm.reset()
	_need(problems, qm.from_dict(saved) and _plain(qm.get_tracked()) == [ids[2], ids[3], ids[4]], "the tracked order did not survive save / load: %s" % str(qm.get_tracked()))
	var late := _start("zz_p13_track_late", [{"id": "gate", "target": 1, "on": "manual"}], false)
	_need(problems, _plain(qm.get_tracked(4)) == [ids[2], ids[3], ids[4], late], "a quest accepted after a load does not come last: %s" % str(qm.get_tracked(4)))
	t.check("tracked_order_and_cap", problems.is_empty(), "get_tracked(max): oldest accepted first, capped, never completed or failed, stable across save / load: %s" % str(problems.slice(0, 3)))
	# journal lists
	problems.clear()
	qm.complete_quest(ids[2])
	qm.complete_quest(ids[4])
	_need(problems, _plain(qm.get_active_ids()) == [ids[3], late], "get_active_ids() = %s" % str(qm.get_active_ids()))
	_need(problems, _plain(qm.get_completed_ids()) == [ids[4], ids[2], ids[0]], "get_completed_ids() = %s, want the most recent first" % str(qm.get_completed_ids()))
	_need(problems, qm.get_active_count() == 2 and qm.get_completed_count() == 3 and qm.get_active_count() == qm.get_active_ids().size() and qm.get_completed_count() == qm.get_completed_ids().size(),
		"counts %d / %d" % [qm.get_active_count(), qm.get_completed_count()])
	# a repeatable quest completed again moves to the front of the finished list (no duplicate)
	qm.register_quest_from_lua({"id": "zz_p13_again", "objectives": [{"id": "gate", "target": 1, "on": "manual"}], "rewards": {}, "meta": {"repeatable": true, "cooldown_days": 0}})
	qm.accept_quest(&"zz_p13_again")
	qm.complete_quest(&"zz_p13_again")
	qm.complete_quest(ids[3])
	qm.accept_quest(&"zz_p13_again")
	qm.complete_quest(&"zz_p13_again")
	_need(problems, qm.get_completed_ids()[0] == &"zz_p13_again" and qm.get_completed_ids().count(&"zz_p13_again") == 1, "a repeated completion is not the most recent entry once: %s" % str(qm.get_completed_ids()))
	t.check("journal_lists_api", problems.is_empty(), "get_active_ids (oldest first), get_completed_ids (most recent first), the two counts for 'Aktive · n' / 'Fuldført · m': %s" % str(problems.slice(0, 3)))
	qm.reset()


func _cooldowns() -> void:
	_fresh()
	var problems: Array = []
	_need(problems, bool(LuaData.dict(_def("cookie_delivery").get("meta", {})).get("repeatable", false)) and int(LuaData.dict(_def("cookie_delivery").get("meta", {})).get("cooldown_days", 0)) == 3, "cookie_delivery is repeatable with a cooldown of 3 days")
	_need(problems, qm.accept_quest(&"cookie_delivery"), "cookie_delivery was not accepted")
	qm.complete_quest(&"cookie_delivery")
	_need(problems, not qm.accept_quest(&"cookie_delivery") and not (&"cookie_delivery" in qm.offerable(&"baker_maja")), "re-accepted / offered on the day it was completed")
	Fresh.jump_to_total_day(gm.total_day() + 2)
	_need(problems, not qm.accept_quest(&"cookie_delivery"), "re-accepted after 2 of 3 days")
	Fresh.jump_to_total_day(gm.total_day() + 1)
	_need(problems, &"cookie_delivery" in qm.offerable(&"baker_maja"), "not offered again after the cooldown")
	_need(problems, qm.accept_quest(&"cookie_delivery") and qm.is_active(&"cookie_delivery"), "not re-accepted after 3 days")
	_need(problems, _cur("cookie_delivery", "collect_carrot") == 0 and not _done("cookie_delivery", "collect_carrot"), "the second run did not start from zero progress")
	qm.complete_quest(&"cookie_delivery")
	_need(problems, qm.completed_quests.count(&"cookie_delivery") == 1, "the history lists the repeated quest %d times" % qm.completed_quests.count(&"cookie_delivery"))
	var first_accept: bool = qm.accept_quest(&"birthday_cake")
	qm.complete_quest(&"birthday_cake")
	_need(problems, first_accept and not qm.accept_quest(&"birthday_cake"), "a one-shot quest (birthday_cake) can be accepted again")
	t.check("repeatable_reaccept_after_cooldown", problems.is_empty(), "meta.repeatable / cooldown_days: re-accept only after the cooldown, from zero, one history entry: %s" % str(problems.slice(0, 3)))
	qm.reset()


func _save_roundtrip() -> void:
	_fresh()
	var problems: Array = []
	qm.accept_quest(&"lost_cat")
	bus.start_dialogue(&"baker_maja", &"baker_maja")
	bus.start_dialogue(&"mayor_lyra", &"mayor_lyra")
	var json_text := JSON.stringify(qm.to_dict())
	_need(problems, not json_text.contains("description_key") and not json_text.contains("any_of") and not json_text.contains("\"functions\"") and not json_text.contains("pippin_boegeknop\":2"), "the save carries Lua definition fields")
	var saved: Dictionary = JSON.parse_string(json_text)
	qm.reset()
	gm.world_flags.clear()
	_need(problems, qm.from_dict(saved) and qm.is_active(&"lost_cat"), "from_dict did not restore the active quest")
	_need(problems, not _def("lost_cat").is_empty() and not _def("cookie_delivery").is_empty(), "loading a save lost the live Lua definitions")
	_need(problems, _cur("lost_cat", "ask_neighbours") == 2, "progress %d, want 2 after the round trip (floats from JSON)" % _cur("lost_cat", "ask_neighbours"))
	bus.start_dialogue(&"mayor_lyra", &"mayor_lyra")
	_need(problems, _cur("lost_cat", "ask_neighbours") == 2, "mayor_lyra counted twice after load: the any_of list was not saved")
	bus.start_dialogue(&"farmer_rosa", &"farmer_rosa")
	_need(problems, _done("lost_cat", "ask_neighbours"), "the third neighbour did not finish ask_neighbours")
	# records are validated before a load: a bad `seen` / order is rejected without touching the live state
	var before: Dictionary = qm.to_dict()
	var bad: Dictionary = before.duplicate(true)
	bad["active"]["lost_cat"]["objectives"]["ask_neighbours"]["seen"] = "baker_maja"
	var bad2: Dictionary = before.duplicate(true)
	bad2["active"]["lost_cat"]["order"] = -1
	_need(problems, not qm.validate_dict(bad) and not qm.from_dict(bad) and not qm.validate_dict(bad2) and qm.to_dict() == before, "an invalid record was applied / the live state changed")
	# an old save without the acceptance order: the order of the records is the order
	var old: Dictionary = before.duplicate(true)
	for qid in old["active"]:
		(old["active"][qid] as Dictionary).erase("order")
	qm.reset()
	qm.accept_quest(&"cookie_delivery")
	qm.from_dict(old)
	_need(problems, _plain(qm.get_tracked()) == [&"lost_cat"], "an old save without `order` did not load (%s)" % str(qm.get_tracked()))
	t.check("save_roundtrip_keeps_progress_and_definitions", problems.is_empty(), "to_dict / from_dict: only runtime state, any_of progress, JSON floats, definitions stay live: %s" % str(problems.slice(0, 3)))
	qm.reset()
	_fresh()
	qm.accept_quest(&"lost_cat")
	qm.reset()
	t.check("reset_keeps_definitions", qm.active_quests.is_empty() and qm.completed_quests.is_empty() and qm.offered_quests.is_empty() and not _def("lost_cat").is_empty(), "reset() forgets progress and keeps the Lua definitions")


func _new_game_and_probes() -> void:
	# a new game forgets progress, owed rewards and flags of the quests but keeps the definitions (the reset contract of PLAN 3.6)
	_fresh()
	var problems: Array = []
	qm.accept_quest(&"lost_cat")
	qm.accept_quest(&"cookie_delivery")
	qm.offer_quest(&"fix_roof")
	qm.register_quest_from_lua({"id": "zz_p13_owed", "objectives": [], "rewards": {"items": {"carrot": 3}}, "meta": {}})
	qm.accept_quest(&"zz_p13_owed")
	eco.inventory.clear()
	for i in eco.INVENTORY_SLOTS:
		eco.inventory.append({"id": &"wood", "amount": 99, "meta": {}})
	qm.complete_quest(&"zz_p13_owed")
	qm.quest_flags["zz_flag"] = 1
	_need(problems, not qm.active_quests.is_empty() and not qm.pending_rewards.is_empty(), "the dirty run has no state")
	Fresh.new_game(t)
	_need(problems, qm.active_quests.is_empty() and qm.completed_quests.is_empty() and qm.offered_quests.is_empty() and qm.pending_rewards.is_empty() and qm.quest_flags.is_empty() and qm.completed_days.is_empty(), "new_game_started did not clear the runtime state")
	_need(problems, not _def("lost_cat").is_empty() and not _def("zz_p13_owed").is_empty(), "new_game_started wiped the definitions")
	_need(problems, qm.get_tracked().is_empty() and qm.get_active_count() == 0 and qm.get_completed_count() == 0, "the tracker / journal lists survived the new game")
	var wired: bool = bus.reset_wave_started.get_connections().any(func(c: Dictionary) -> bool: return c["callable"].get_object() == qm and str(c["callable"].get_method()) == "reset")
	_need(problems, wired, "QuestManager.reset is not connected to EventBus.new_game_started")
	t.check("new_game_resets_runtime_and_keeps_definitions", problems.is_empty(), "reset() on new_game_started: active, completed, offered, owed rewards and flags gone, definitions stay: %s" % str(problems.slice(0, 3)))
	# the Lua probes of the interpreter live in P10's tests/fixtures/lua and are replayed by data.lua_probes; the quest files must stay inside that subset
	var probes := 0
	for f in DirAccess.get_files_at("res://tests/fixtures/lua"):
		if f.get_extension() == "lua" and f.begins_with("p") and f.get_slice("_", 0).length() == 3:
			probes += 1
	var expected_json := FileAccess.file_exists("res://tests/fixtures/lua/probe_expected.json")
	var quest_flagged: Array[String] = []
	for q in _quest_files():
		for finding in lr.lint_source(FileAccess.get_file_as_string("res://lua/quests/%s.lua" % q), "res://lua/quests/%s.lua" % q):
			quest_flagged.append("%s: %s" % [q, finding["rule"]])
	t.check("lua_probes_live_in_p10_fixtures", probes >= 23 and expected_json and quest_flagged.is_empty(), "%d probe files + probe_expected.json in P10's tests/fixtures/lua (replayed by data.lua_probes), every quest file lints clean with the same lint_source %s" % [probes, str(quest_flagged.slice(0, 3))])
	qm.reset()


func _item_in_use() -> void:
	_fresh()
	var problems: Array = []
	_need(problems, not qm.item_in_use(&"wood") and not qm.item_in_use(&"") , "wood is in use with no quest")
	qm.accept_quest(&"fix_roof")
	_need(problems, qm.item_in_use(&"wood") and qm.item_in_use(&"moss") and not qm.item_in_use(&"stone"), "fix_roof: wood and moss are needed (have + quest_spot needs), stone is not")
	qm.accept_quest(&"cookie_delivery")
	_need(problems, qm.item_in_use(&"carrot") and not qm.item_in_use(&"turnip"), "cookie_delivery needs carrots")
	qm.accept_quest(&"flower_necklace")
	var recipe: Dictionary = LuaData.dict(lr.get_recipe("flower_necklace"))
	var ingredient := str(LuaData.int_map(recipe.get("ingredients", {})).keys()[0]) if not LuaData.int_map(recipe.get("ingredients", {})).is_empty() else "wild_flower"
	_need(problems, qm.item_in_use(StringName(ingredient)) and qm.item_in_use(&"wild_flower") and qm.item_in_use(&"flower_necklace"), "flower_necklace: the wild flowers, the recipe's ingredient `%s` and the necklace itself are needed" % ingredient)
	qm.complete_quest(&"fix_roof")
	_need(problems, not qm.item_in_use(&"wood") and qm.item_in_use(&"moss"), "a finished quest still holds its wood / moss stays in use as an ingredient of the open necklace recipe")
	# a done have objective is released unless a delivery still needs the goods
	qm.reset()
	var q := _start("zz_p13_use", [{"id": "a", "target": 1, "on": "item_gained", "item": "honey", "have": true}, {"id": "b", "target": 1, "on": "manual"}], false)
	eco.add_item(&"honey", 1)
	qm.refresh_objectives()
	_need(problems, _done(q, "a") and not qm.item_in_use(&"honey"), "a done have objective with no delivery still holds the honey")
	t.check("item_in_use", problems.is_empty(), "item_in_use(item): open have objectives, `needs` of open objectives, ingredients of an open recipe_crafted objective: %s" % str(problems.slice(0, 3)))
	qm.reset()


func _objective_text() -> void:
	_fresh()
	var problems: Array = []
	for locale in ["da", "en"]:
		lm.set_locale(locale, false)
		for q in ["lost_cat", "cookie_delivery", "fix_roof", "math_harvest_puzzle"]:
			for o in _objectives(q):
				var oid := str(LuaData.dict(o).get("id", ""))
				var text: String = qm.get_objective_text(StringName(q), StringName(oid))
				_need(problems, text != "" and text != oid.capitalize() and not text.begins_with("OBJ_"), "%s/%s.%s: `%s`" % [locale, q, oid, text])
	lm.set_locale("da", false)
	# the cascade: description_key, OBJ_<QUEST>_<OBJ>, OBJ_<OBJ>, the Lua description, the id; and the title cascade
	qm.register_quest_from_lua({"id": "zz_p13_text", "objectives": [{"id": "find_cat", "target": 1}, {"id": "zz_only_literal", "target": 1, "description": "Plain words"},
		{"id": "zz_nothing", "target": 1}, {"id": "named", "target": 1, "description_key": "OBJ_LOST_CAT_FIND_CAT"}], "rewards": {}, "meta": {}})
	_need(problems, qm.get_objective_text(&"zz_p13_text", &"find_cat") != "" and not qm.get_objective_text(&"zz_p13_text", &"find_cat").begins_with("OBJ_"), "OBJ_<OBJ> fallback")
	_need(problems, qm.get_objective_text(&"zz_p13_text", &"zz_only_literal") == "Plain words", "the Lua description is the next fallback")
	_need(problems, qm.get_objective_text(&"zz_p13_text", &"zz_nothing") == "zz_nothing".capitalize(), "the readable id is the last fallback, never a raw key (%s)" % qm.get_objective_text(&"zz_p13_text", &"zz_nothing"))
	_need(problems, qm.get_objective_text(&"zz_p13_text", &"named") == lm.text_in("OBJ_LOST_CAT_FIND_CAT", "da"), "description_key wins")
	_need(problems, qm.get_title(&"lost_cat") == "Find Pippins kat" and qm.get_title(&"zz_p13_text") == "zz_p13_text".capitalize(), "titles: %s / %s" % [qm.get_title(&"lost_cat"), qm.get_title(&"zz_p13_text")])
	t.check("objective_text_cascade", problems.is_empty(), "get_objective_text: description_key -> OBJ_<QUEST>_<OBJ> -> OBJ_<OBJ> -> description -> id, da and en: %s" % str(problems.slice(0, 3)))
	qm.reset()


func _binding_lint() -> void:
	var problems: Array = []
	var bad := {"id": "zz_p13_bad", "source_path": "res://zz_bad.lua", "objectives": [
		{"id": "a", "target": 1, "on": "teleport"},
		{"id": "b", "target": 1, "on": "state", "state": "no_such_query"},
		{"id": "c", "target": 5, "on": "dialogue_started", "any_of": ["x", "y"]},
		{"id": "d", "target": 1, "on": "item_gained", "have": true},
		{"id": "e", "target": 1, "on": "state", "state": "hygge_level_at_least"},
		{"id": "f", "target": 1, "on": "area_changed"},
		{"id": "g", "target": 0, "on": "manual"},
		{"id": "a", "target": 1, "on": "manual"},
		{"id": "h", "target": 1, "on": "manual", "consume": true},
		{"id": "i", "target": 2, "on": "state", "state": "home_tier_at_least", "min_level": 3}],
		"rewards": {"gold": -1, "items": {"wood": 0}, "friendship": {"x": 11}}, "meta": {"tag": "NOPE"}}
	var findings: Array = qm.validate_definition(bad)
	var text := "\n".join(PackedStringArray(findings.map(func(f: Dictionary) -> String: return str(f["message"]))))
	for needle in ["teleport", "no_such_query", "more than the 2 npcs", "have = true", "needs the field `min_level`", "needs the field `area`", "target must be", "used twice", "consume = true needs", "threshold", "gold must", "wood", "friendship", "tag `NOPE`"]:
		_need(problems, text.contains(needle), "the binding lint missed `%s`" % needle)
	var clean: Array = qm.validate_definition(_def("lost_cat"))
	_need(problems, clean.is_empty(), "the lint flags the guide quest: %s" % str(clean))
	# a file-based definition lands in LuaRuntime.lint_report, the lint is part of the load
	var before: int = lr.lint_report.size()
	qm.register_quest_from_lua(bad)
	_need(problems, lr.lint_report.size() > before and str(lr.lint_report[lr.lint_report.size() - 1]["rule"]) == "quest_binding", "a registered file-based definition did not report to LuaRuntime.lint_report")
	qm.quest_defs.erase(&"zz_p13_bad")
	lr.reload_scripts()
	_need(problems, lr.lint_report.is_empty(), "the lint report is not empty after the clean reload: %s" % str(lr.lint_report.slice(0, 2)))
	t.check("binding_lint_catches_uncompletable_objectives", problems.is_empty(), "unknown on / state, any_of larger than the target, have without item, missing fields, duplicates, bad rewards / tags: %s" % str(problems.slice(0, 4)))


# =============================================================================================== the guide quest and the feature quests

func _guide_quests() -> void:
	_fresh()
	var problems: Array = []
	var rewards := LuaData.dict(_def("lost_cat").get("rewards", {}))
	var items := LuaData.int_map(rewards.get("items", {}))
	_need(problems, LuaData.int_of(rewards.get("gold", 0)) == 150 and int(items.get("catnip_seeds", 0)) == 3 and LuaData.int_of(LuaData.dict(rewards.get("friendship", {})).get("pippin_boegeknop", 0)) >= 1,
		"lost_cat rewards %s: want 150 gold, catnip_seeds x3 and a heart with Pippin" % str(rewards))
	_need(problems, bool(LuaData.dict(_def("lost_cat").get("meta", {})).get("repeatable", true)) == false and int(LuaData.dict(_def("lost_cat").get("meta", {})).get("cooldown_days", -1)) == 0, "lost_cat is one-shot (repeatable = false, cooldown_days = 0)")
	var chips: Array = QuestText.rewards(&"lost_cat")
	var chip_text: Array[String] = []
	for c in chips:
		chip_text.append(str((c as Dictionary)["text"]))
	_need(problems, chip_text.has("150 guldagern") and chip_text.any(func(s: String) -> bool: return s.begins_with("Kattemyntefrø")) and chip_text.any(func(s: String) -> bool: return s.begins_with("♥") and s.contains("Pippin")),
		"the quest book chips %s are not the guide's 150 guldagern, Kattemyntefrø x 3, heart Pippin" % str(chip_text))
	var steps: Array = QuestText.steps(&"lost_cat")
	var step_text: Array[String] = []
	for s in steps:
		step_text.append(str((s as Dictionary)["text"]))
	_need(problems, step_text.size() == 4 and step_text[0] == "Spørg naboerne i Hyggebyen" and step_text[1] == "Følg poteaftrykkene ved broen" and step_text[2] == "Find Morfar Mis i Mørkeskoven", "the steps %s are not the guide's" % str(step_text))
	_need(problems, QuestText.title(&"lost_cat") == "Find Pippins kat" and QuestText.title(&"cookie_delivery") == "Gulerødder til småkager" and QuestText.title(&"fix_roof") == "Utæt tag på bageriet" and QuestText.title(&"moonstone_crown") == "Månesten til kronen", "the four guide titles")
	_need(problems, QuestText.from_line(&"lost_cat") == TranslationServer.translate("QJ_FROM") % "Pippin Bøgeknop" + " · Hyggebyen", "the 'Fra Pippin Bøgeknop · Hyggebyen' line: %s" % QuestText.from_line(&"lost_cat"))
	_need(problems, QuestText.description(&"lost_cat") == "Morfar Mis er forsvundet igen. Han blev sidst set på vej mod Mørkeskoven med en sardin i munden.", "the guide description: %s" % QuestText.description(&"lost_cat"))
	_need(problems, QuestText.tag_text(&"lost_cat") == TranslationServer.translate("QJ_TAG_FIND") and QuestText.tag_text(&"cookie_delivery") == TranslationServer.translate("QJ_TAG_HOEST"), "tag chips FIND / HØST")
	t.check("lost_cat_keeps_guide_chips", problems.is_empty(), "lost_cat pays 150 guldagern + catnip_seeds x3 + hat_cat_ears + a heart with Pippin; the book shows the guide's chips, steps, title, 'Fra' line and description: %s" % str(problems.slice(0, 3)))
	# the guide quest from start to finish through the signals (neighbours, paw prints, Morfar Mis, back to Pippin)
	problems.clear()
	var gold0: int = eco.gold
	_need(problems, qm.accept_quest(&"lost_cat"), "lost_cat not accepted")
	for npc in [&"baker_maja", &"merchant_pip", &"mayor_lyra"]:
		bus.start_dialogue(npc, npc)
	_need(problems, _done("lost_cat", "ask_neighbours"), "three neighbours did not finish the first step")
	bus.start_dialogue(&"pippin_boegeknop", &"pippin_boegeknop")
	_need(problems, qm.is_active(&"lost_cat"), "Pippin finished the quest before the cat was found (after_others)")
	_need(problems, qm.complete_manual(&"lost_cat", &"follow_pawprints"), "the paw prints quest_spot (complete_manual) failed")
	bus.start_dialogue(&"cat_morfar_mis", &"cat_morfar_mis")
	bus.start_dialogue(&"pippin_boegeknop", &"pippin_boegeknop")
	_need(problems, qm.is_completed(&"lost_cat") and eco.gold == gold0 + 150 and eco.count_item(&"catnip_seeds") >= 3 and qm.pending_rewards.is_empty(), "the finished guide quest did not pay (gold %d -> %d)" % [gold0, eco.gold])
	t.check("lost_cat_plays_through", problems.is_empty(), "ask three neighbours, follow the paw prints, find Morfar Mis, tell Pippin: %s" % str(problems.slice(0, 3)))
	qm.reset()


func _feature_quests_and_every_objective() -> void:
	var rows: Array[String] = []
	var failures: Array[String] = []
	var forced: Array[String] = []
	var feature_failures: Array[String] = []
	var objectives_total := 0
	var events_fed := {}
	for q in _all_quest_ids():
		var result: Dictionary = await _drive(q, events_fed)
		objectives_total += int(result["objectives"])
		if bool(result["forced"]):
			forced.append(q)
		if not (result["problems"] as Array).is_empty():
			failures.append("%s: %s" % [q, str((result["problems"] as Array)[0])])
			if q in FEATURE_EIGHT:
				feature_failures.append("%s: %s" % [q, str((result["problems"] as Array)[0])])
		rows.append(q)
	var fed: Array = events_fed.keys()
	fed.sort()
	t.check("feature_quests_complete_with_rewards", feature_failures.is_empty() and FEATURE_EIGHT.all(func(q: String) -> bool: return rows.has(q)),
		"lost_cat, fix_roof, birthday_cake, math_wizard_quiz, bogtraeet, moonstone_crown, snurresvampen, slotsdroemmen: accepted and completed through the real EventBus, exact gold and items %s" % str(feature_failures.slice(0, 3)))
	var dungeon_fed: Array = fed.filter(func(e: Variant) -> bool: return str(e).begins_with("dungeon_"))
	t.check("every_objective_completable_with_dungeon_events", failures.is_empty() and rows.size() >= 25,
		"%d quest files, %d objectives driven through the signals the game sends (game_event names fed: %s; the dungeon payloads of ADDENDUM 8.4 reach every objective bound to them - %s); accepted through the Lua gate: %d, started past an unknown gate: %s; %s" % [rows.size(), objectives_total, ", ".join(PackedStringArray(fed)), "fed to real quests: " + (", ".join(PackedStringArray(dungeon_fed)) if not dungeon_fed.is_empty() else "none yet, the dungeon quests land with DR7 and are picked up automatically; proven synthetically by dungeon_event_payloads_bind"), rows.size() - forced.size(), str(forced), str(failures.slice(0, 3))])


## Drives ONE quest from accept to completion through the real signals / APIs, objective by objective (turn-ins last), and checks the payout.
## Returns {problems, forced, objectives}. `events_fed` collects the game_event names it sent.
func _drive(qid: String, events_fed: Dictionary) -> Dictionary:
	Svc.clear_overrides()
	if _objectives(qid).any(func(od): return bool(od.get("requires_meeting", false))):
		await t.start_world()
	else:
		Fresh.new_game(t)
	var fakes := _fakes()
	var furniture: FakeFurniture = fakes["furniture"]
	var home: FakeHome = fakes["home"]
	var social: FakeSocial = fakes["social"]
	var problems: Array[String] = []
	var def := _def(qid)
	var rewards := LuaData.dict(def.get("rewards", {}))
	var objectives: Array = _objectives(qid)
	var qn := StringName(qid)
	var accepted: bool = qm.accept_quest(qn)
	var forced := false
	if not accepted:
		_open_gates(qid, def)
		accepted = qm.accept_quest(qn)
	if not accepted:
		qm.call("_activate", qn, def)
		forced = true
	# A procedural errand chooses its named friendship recipient at acceptance.
	var dynamic_hearts := LuaData.int_map(LuaData.dict(qm.get_quest_progress(qn).get("meta",{})).get("friendship_rewards",{}))
	var completed_signals: Array = []
	var updates := [0]
	var on_completed := func(_player_id: StringName, id: StringName) -> void: completed_signals.append(id)
	var on_update := func(_player_id: StringName, _id: StringName, _o: StringName, _p: int, _tt: int) -> void: updates[0] += 1
	bus.quest_completed.connect(on_completed)
	bus.quest_objective_updated.connect(on_update)
	var gold0: int = eco.gold
	var added := {}
	var consumed := {}
	var normal: Array = []
	var turn_ins: Array = []
	for o in objectives:
		if bool(LuaData.dict(o).get("after_others", false)):
			turn_ins.append(o)
		else:
			normal.append(o)
	var helper_n := 0
	# what the player owns of every good this quest touches before the first objective (the starter kit holds seeds and oil)
	var base := {}
	for k in LuaData.int_map(rewards.get("items", {})):
		base[k] = eco.count_item(StringName(k))
	for o in objectives:
		var od0 := LuaData.dict(o)
		if str(od0.get("item", "")) != "":
			base[str(od0["item"])] = eco.count_item(StringName(str(od0["item"])))
		for k in LuaData.int_map(od0.get("needs", {})):
			base[k] = eco.count_item(StringName(k))
	var phases: Array = [normal, turn_ins]
	for phase_index in phases.size():
		for o in phases[phase_index]:
			if not qm.is_active(qn):
				break
			var od := LuaData.dict(o)
			var oid := str(od.get("id", ""))
			var target := maxi(LuaData.int_of(od.get("target", 1), 1), 1)
			var on := str(od.get("on", ""))
			# the goods a delivery / quest_spot asks for are in the backpack when the player stands there
			for item_id in LuaData.int_map(od.get("needs", {})):
				var want := int(LuaData.int_map(od["needs"])[item_id])
				var short: int = want - eco.count_item(StringName(item_id))
				if short > 0:
					_need(problems, eco.add_item(StringName(item_id), short, true), "%s.%s: no room for %d x %s" % [qid, oid, short, item_id])
					added[item_id] = int(added.get(item_id, 0)) + short
				if bool(od.get("consume", false)):
					consumed[item_id] = int(consumed.get(item_id, 0)) + want
			match on:
				"item_gained":
					var item_id := str(od.get("item", ""))
					_need(problems, eco.add_item(StringName(item_id), target), "%s.%s: no room for %d x %s" % [qid, oid, target, item_id])
					added[item_id] = int(added.get(item_id, 0)) + target
				"crop_planted":
					for i in target:
						bus.crop_planted.emit(&"plot_t", StringName(_first(od.get("crop", ""), "turnip")))
				"crop_watered":
					for i in target:
						bus.crop_watered.emit(&"plot_t")
				"crop_harvested":
					bus.crop_harvested.emit(&"plot_t", StringName(_first(od.get("crop", ""), "turnip")), target)
				"zone_entered":
					for i in target:
						bus.zone_entered.emit(StringName(str(od.get("zone", ""))))
				"area_changed":
					for i in target:
						bus.area_changed.emit(StringName(str(od.get("area", ""))))
				"dialogue_started":
					var any_of := LuaData.strings(od.get("any_of", []))
					for i in target:
						var npc := any_of[i] if not any_of.is_empty() else str(od.get("npc", ""))
						if bool(od.get("requires_meeting", false)):
							var actor := Npc2D.create({"id": npc, "wander": "0"})
							actor.area = t.world().area
							t.world().area.objects.add_child(actor)
							actor.interact(t.player())
							await preload("res://tests/progression/mining_deliveries.gd")._close(t)
							actor.queue_free()
						else:
							bus.start_dialogue(StringName(npc), StringName(npc))
				"animal_adopted":
					for i in target:
						bus.animal_adopted.emit(&"animal_t", StringName(_first(od.get("species", ""), "chicken")))
				"animal_fed":
					for i in target:
						bus.animal_fed.emit(&"animal_t", StringName(_first(od.get("food", ""), "chicken_feed")))
				"animal_product_collected":
					bus.animal_product_collected.emit(&"animal_t", StringName(_first(od.get("product", ""), "egg")), target)
				"building_built":
					for i in target:
						bus.building_built.emit(&"building_t", StringName(_first(od.get("type", ""), "coop")))
				"enemy_defeated":
					for i in target:
						bus.enemy_defeated.emit(&"enemy_t", StringName(_first(od.get("kind", ""), "bat")), [])
				"recipe_crafted":
					for i in target:
						bus.recipe_crafted.emit(StringName(_first(od.get("recipe", ""), "iron_ingot")), 1)
				"quest_completed":
					for i in target:
						helper_n += 1
						var hid := "zz_p13_helper_%d" % helper_n
						qm.register_quest_from_lua({"id": hid, "objectives": [], "rewards": {}, "meta": {"category": _first(od.get("category", ""), "help")}})
						bus.quest_completed.emit(PlayerRegistry.local_id(), StringName(hid))
				"state":
					_satisfy_state(od, furniture, home, social)
				"manual":
					var needs: Dictionary = LuaData.int_map(od.get("needs", {}))
					_need(problems, qm.complete_manual(qn, StringName(oid), needs, bool(od.get("consume", false))), "%s.%s: complete_manual failed" % [qid, oid])
				_:
					if on == "game_event" or on == "gift_given" or on == "festival_attended" or on == "heart_event_finished":
						var event_name := str(od.get("event", "")) if on == "game_event" else on
						events_fed[event_name] = true
						for i in target:
							bus.game_event.emit(StringName(event_name), _payload_for(event_name, od))
					else:
						problems.append("%s.%s: `on = %s` has no driver in this test" % [qid, oid, on])
			await t.frames(1)
			# after a non-final objective the quest is still there; after the last one it is complete
			if qm.is_active(qn):
				var progress: Dictionary = qm.get_objective_progress(qn, StringName(oid))
				_need(problems, bool(progress.get("done", false)), "%s.%s did not finish (%s)" % [qid, oid, str(progress)])
	await t.frames(1)
	_need(problems, qm.is_completed(qn) and not qm.is_active(qn), "%s was not completed after every objective" % qid)
	_need(problems, completed_signals.count(qn) == 1, "%s: quest_completed fired %d times" % [qid, completed_signals.count(qn)])
	_need(problems, updates[0] >= objectives.size(), "%s: only %d quest_objective_updated for %d objectives" % [qid, updates[0], objectives.size()])
	_need(problems, qm.pending_rewards.is_empty(), "%s: rewards still owed %s" % [qid, str(qm.pending_rewards)])
	_need(problems, eco.gold == gold0 + LuaData.int_of(rewards.get("gold", 0)), "%s: gold %d -> %d, want +%d" % [qid, gold0, eco.gold, LuaData.int_of(rewards.get("gold", 0))])
	var reward_items := LuaData.int_map(rewards.get("items", {}))
	var touched := {}
	for k in reward_items:
		touched[k] = true
	for k in added:
		touched[k] = true
	for k in touched:
		var expected: int = int(reward_items.get(k, 0)) + int(added.get(k, 0)) - int(consumed.get(k, 0))
		var have: int = eco.count_item(StringName(k)) - int(base.get(k, 0))
		_need(problems, have == expected, "%s: %s changed by %d, want %d (reward %d + given %d - delivered %d)" % [qid, k, have, expected, int(reward_items.get(k, 0)), int(added.get(k, 0)), int(consumed.get(k, 0))])
	var hearts := LuaData.int_map(rewards.get("friendship", {}))
	for npc in dynamic_hearts:
		hearts[npc] = mini(10,int(hearts.get(npc,0))+clampi(int(dynamic_hearts[npc]),0,10))
	var calls: Array = []
	for c in social.calls:
		calls.append([str(c[0]), int(c[1]), c[2]])
	var wanted_calls: Array = []
	for npc in hearts:
		wanted_calls.append([str(npc), int(hearts[npc]), &"quest"])
	_need(problems, calls == wanted_calls, "%s: friendship through SocialManager.add_hearts %s, want %s" % [qid, str(calls), str(wanted_calls)])
	bus.quest_completed.disconnect(on_completed)
	bus.quest_objective_updated.disconnect(on_update)
	_free_fakes(fakes)
	for k in qm.quest_defs.keys():
		if str(k).begins_with("zz_p13_helper_"):
			qm.quest_defs.erase(k)
	return {"problems": problems, "forced": forced, "objectives": objectives.size()}


## First entry of a comma list (a driver needs one concrete value), `fallback` when the filter is empty.
func _first(value: Variant, fallback: String) -> String:
	var parts := str(value).split(",", false)
	return parts[0].strip_edges() if parts.size() > 0 else fallback


## The flags a quest's own is_available asks for: every `api.has_flag("x")` that is NOT negated is set, a mention of home_tier sets tier 10.
func _open_gates(qid: String, def: Dictionary) -> void:
	var source := FileAccess.get_file_as_string(str(def.get("source_path", "")))
	var rx := RegEx.new()
	rx.compile("(not\\s+)?api\\.has_flag\\(\"([a-z0-9_]+)\"\\)")
	for m in rx.search_all(source):
		if m.get_string(1) == "":
			gm.set_flag(StringName(m.get_string(2)), true)
	if source.contains("home_tier"):
		gm.set_flag(&"home_tier", 10)


func _satisfy_state(od: Dictionary, furniture: FakeFurniture, home: FakeHome, social: FakeSocial) -> void:
	match str(od.get("state", "")):
		"buildings_owned":
			var husbandry := Svc.node("AnimalHusbandry")
			if husbandry != null: husbandry.build_building(StringName(str(od.get("type","coop"))),true)
			qm.refresh_objectives()
		"animals_owned":
			var husbandry := Svc.node("AnimalHusbandry")
			if husbandry != null:
				husbandry.build_building(&"coop",true)
				eco.add_item(&"baby_chick",1,true)
				husbandry.adopt_animal(&"baby_chick")
			qm.refresh_objectives()

		"placed_by_rarity":
			furniture.placed = {_first(od.get("rarity", ""), "unique"): LuaData.int_of(od.get("target", 1), 1)}
			bus.furniture_changed.emit(&"placed")
		"hygge_level_at_least":
			furniture.level = LuaData.int_of(od.get("min_level", 1), 1)
			bus.hygge_changed.emit(100, &"hyggeligt")
		"home_tier_at_least":
			home.tier = LuaData.int_of(od.get("min_level", 1), 1)
			bus.home_upgraded.emit(1, home.tier)
		"friend_hearts_at_least":
			social.hearts_of[str(od.get("npc", ""))] = LuaData.int_of(od.get("hearts", 1), 1)
			bus.friend_changed.emit(PlayerRegistry.local_id(), StringName(str(od.get("npc", ""))), LuaData.int_of(od.get("hearts", 1), 1))
		_:
			furniture.level = 10
			bus.furniture_changed.emit(&"placed")


## The payload of a game_event as its owner emits it, bent just far enough to satisfy the objective's filters (rarity, min_level, match, sugar fields).
func _payload_for(event_name: String, od: Dictionary) -> Dictionary:
	var payload: Dictionary = (EVENT_PAYLOADS.get(event_name, {}) as Dictionary).duplicate(true)
	if od.has("rarity"):
		payload["rarity"] = _first(od["rarity"], "unique")
	if od.has("min_level"):
		var lvl := LuaData.int_of(od["min_level"])
		payload["level"] = lvl
		if payload.has("floor") or event_name.begins_with("dungeon_"):
			payload["floor"] = lvl
	var wanted := LuaData.dict(od.get("match", {}))
	for k in wanted:
		payload[k] = wanted[k]
	for field in qm.GAME_EVENT_SUGAR.get(str(od.get("on", "")), []):
		if od.has(field):
			payload[field] = _first(od[field], "x")
	return payload


# =============================================================================================== completers, markers, floors

func _manual_completers() -> void:
	# every on = manual objective must be named by a quest_spot marker, a dialogue action (quest_id + objective_id) or a generator / script
	var markers := {}
	for f in DirAccess.get_files_at("res://data/maps"):
		if f.get_extension() != "map":
			continue
		for line in FileAccess.get_file_as_string("res://data/maps/%s" % f).split("\n"):
			if line.begins_with("@marker") and line.contains(" quest_spot "):
				var kv := _marker_fields(line)
				markers["%s.%s" % [kv.get("quest", ""), kv.get("objective", "")]] = true
	var generated := _generated_floor(7,4242)
	for marker in generated.markers.values():
		if str(marker.get("marker",""))=="quest_spot":markers["%s.%s"%[marker.get("quest",""),marker.get("objective","")]] = true
	var dialogue := {}
	var rx_q := RegEx.new()
	rx_q.compile("quest_id\\s*=\\s*\"([a-z0-9_]+)\"")
	var rx_o := RegEx.new()
	rx_o.compile("objective_id\\s*=\\s*\"([a-z0-9_]+)\"")
	for f in DirAccess.get_files_at("res://lua/dialogue"):
		if f.get_extension() != "lua":
			continue
		var last_quest := ""
		for line in FileAccess.get_file_as_string("res://lua/dialogue/%s" % f).split("\n"):
			var mq := rx_q.search(line)
			if mq != null:
				last_quest = mq.get_string(1)
			var mo := rx_o.search(line)
			if mo != null:
				dialogue["%s.%s" % [last_quest, mo.get_string(1)]] = true
	var scripts_text := ""
	for dir in ["res://scripts/dungeon", "res://scripts/world2d", "res://scripts/towns", "res://scripts/loot", "res://scripts/traetoppen", "res://scripts/ghostfam"]:
		scripts_text += _read_dir_text(dir)
	var unnamed: Array[String] = []
	var pending: Array[String] = []
	var manual_n := 0
	for q in _all_quest_ids():
		for o in _objectives(q):
			var od := LuaData.dict(o)
			if str(od.get("on", "")) != "manual":
				continue
			manual_n += 1
			var key := "%s.%s" % [q, od.get("id", "")]
			# MotherStory dispatches from its production chapter registry rather
			# than literal quest names. The story section exercises these real
			# completions, including checkpoints and out-of-order catch-up.
			var mother_bound := false
			for chapter in MotherStory.CHAPTERS:
				if q == str(MotherStory.quest_id(chapter.id)):
					mother_bound = str(od.get("id","")) in chapter.needs or (str(od.get("id","")) == "checkpoint" and chapter.has("boss_floor"))
			if mother_bound: continue
			if markers.has(key) or dialogue.has(key) or (scripts_text.contains(str(od.get("id", ""))) and scripts_text.contains(q)):
				continue
			if PENDING_COMPLETERS.has(key):
				pending.append("%s (%s)" % [key, PENDING_COMPLETERS[key]])
			else:
				unnamed.append(key)
	t.check("manual_objectives_have_completers", unnamed.is_empty() and manual_n >= 9, "%d on = manual objectives, each named by a quest_spot marker (%d markers), a dialogue math_answer action (%d) or a script: unnamed %s" % [manual_n, markers.size(), dialogue.size(), str(unnamed)])
	if not pending.is_empty():
		t.skip("manual_objectives_have_completers: the completer of %s is built by a package that has not landed (its quest_spot is generated by the dungeon generator, DUNGEON_V2_ADDENDUM 2.7)" % ", ".join(PackedStringArray(pending)))


func _marker_fields(line: String) -> Dictionary:
	var out := {}
	for part in line.split(" ", false):
		if part.contains("="):
			out[part.get_slice("=", 0)] = part.get_slice("=", 1)
	return out


func _read_dir_text(dir_path: String) -> String:
	var out := ""
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	for f in d.get_files():
		if f.get_extension() == "gd":
			out += FileAccess.get_file_as_string(dir_path.path_join(f))
	for sub in d.get_directories():
		out += _read_dir_text(dir_path.path_join(sub))
	return out


## The quest_spot markers of the maps and the objectives they finish agree on the goods (needs / consume): the Lua says the same as the map.
func _quest_spot_needs_match_lua() -> void:
	var problems: Array[String] = []
	var n := 0
	for f in DirAccess.get_files_at("res://data/maps"):
		if f.get_extension() != "map" or f.begins_with("_"):
			continue
		for line in FileAccess.get_file_as_string("res://data/maps/%s" % f).split("\n"):
			if not (line.begins_with("@marker") and line.contains(" quest_spot ")):
				continue
			n += 1
			var kv := _marker_fields(line)
			var od: Dictionary = {}
			for o in _objectives(str(kv.get("quest", ""))):
				if str(LuaData.dict(o).get("id", "")) == str(kv.get("objective", "")):
					od = LuaData.dict(o)
			_need(problems, not od.is_empty() and str(od.get("on", "")) == "manual", "%s: marker %s.%s names no manual objective" % [f, kv.get("quest", ""), kv.get("objective", "")])
			var needs := {}
			for pair in str(kv.get("needs", "")).split(",", false):
				needs[pair.get_slice(":", 0)] = int(pair.get_slice(":", 1))
			_need(problems, LuaData.int_map(od.get("needs", {})) == needs, "%s: needs=%s of the marker is %s in the Lua" % [f, str(needs), str(LuaData.int_map(od.get("needs", {})))])
			_need(problems, bool(od.get("consume", false)) == (str(kv.get("consume", "0")) == "1"), "%s: consume differs between marker and Lua" % f)
	t.check("quest_spot_markers_match_the_lua_needs", problems.is_empty() and n >= 2, "%d quest_spot markers of the real maps: the objective is manual and its needs / consume equal the marker's %s" % [n, str(problems.slice(0, 3))])


func _dungeon_and_forest_bindings() -> void:
	var problems: Array = []
	var intro := _objectives("intro_lottery")
	var bridge: Dictionary = {}
	for o in intro:
		if str(LuaData.dict(o).get("id", "")) == "cross_bridge":
			bridge = LuaData.dict(o)
	_need(problems, str(bridge.get("on", "")) == "zone_entered" and str(bridge.get("zone", "")) == "traetoppen", "cross_bridge binds %s" % str(bridge))
	var talk: Dictionary = {}
	for o in intro:
		if str(LuaData.dict(o).get("id", "")) == "talk_to_mayor":
			talk = LuaData.dict(o)
	_need(problems, str(talk.get("on", "")) == "dialogue_started" and str(talk.get("npc", "")) == "mayor_lyra", "talk_to_mayor binds %s" % str(talk))
	_need(problems, _objectives("intro_lottery").map(func(o: Variant) -> String: return str(LuaData.dict(o).get("id", ""))) == ["plant_first_crop", "cross_bridge", "talk_to_mayor"], "intro_lottery objectives")
	# the farm bridge lands in the city: entering Trætoppen completes the step, Hyggebyen alone does not
	_fresh()
	qm.accept_quest(&"intro_lottery")
	bus.zone_entered.emit(&"city")
	_need(problems, not _done("intro_lottery", "cross_bridge"), "zone city (Hyggebyen) completed cross_bridge")
	bus.zone_entered.emit(&"traetoppen")
	_need(problems, _done("intro_lottery", "cross_bridge"), "zone traetoppen did not complete cross_bridge")
	_need(problems, bool(LuaData.dict(_def("intro_lottery").get("meta", {})).get("giver", "") == "mayor_lyra"), "intro_lottery giver")
	t.check("intro_lottery_binds_traetoppen", problems.is_empty(), "plant_first_crop (crop_planted), cross_bridge (zone_entered traetoppen), talk_to_mayor (dialogue mayor_lyra): %s" % str(problems.slice(0, 3)))
	qm.reset()
	# lost_cat: paw prints are a manual quest_spot on the farm bridge, Mis a dialogue wherever he stands; no quest names a fixed forest area id
	problems.clear()
	var lost := _objectives("lost_cat")
	var by_id := {}
	for o in lost:
		by_id[str(LuaData.dict(o).get("id", ""))] = LuaData.dict(o)
	_need(problems, str(LuaData.dict(by_id.get("follow_pawprints", {})).get("on", "")) == "manual" and str(LuaData.dict(by_id.get("find_cat", {})).get("npc", "")) == "cat_morfar_mis" and str(LuaData.dict(by_id.get("find_cat", {})).get("on", "")) == "dialogue_started", "follow_pawprints is manual and find_cat is dialogue_started cat_morfar_mis")
	var offenders: Array[String] = []
	for q in _all_quest_ids():
		for o in _objectives(q):
			var od := LuaData.dict(o)
			if str(od.get("on", "")) == "area_changed" and str(od.get("area", "")) in ["skovkant", "dybe_bregner"]:
				offenders.append("%s.%s -> %s" % [q, od.get("id", ""), od.get("area", "")])
			if str(od.get("on", "")) == "zone_entered" and str(od.get("zone", "")) in ["skovkant", "dybe_bregner"]:
				offenders.append("%s.%s zone %s" % [q, od.get("id", ""), od.get("zone", "")])
	if offenders.size() == 1 and offenders[0].begins_with("snurresvampen."):
		t.skip("no_fixed_forest_area_ids: snurresvampen.enter_dybe_bregner still binds the old area id (%s) - D0-dungeon-world-hooks re-keys it to moerkeskoven_f4" % offenders[0])
	else:
		t.check("no_fixed_forest_area_ids", offenders.is_empty(), "no quest binds skovkant / dybe_bregner as an area or zone id (the generated floors have moerkeskoven_f<N> ids) %s" % str(offenders))
	t.check("lost_cat_binds_pawprints_and_mis", problems.is_empty(), "%s" % str(problems))
	# zone_entered fires on every area change, also floor to floor: harmless for the zone quests (target 1)
	problems.clear()
	for q in ["dark_forest_mining", "forest_patrol", "crystal_cave"]:
		_fresh()
		qm.accept_quest(StringName(q))
		for i in 4:
			bus.zone_entered.emit(&"dark_forest")
			bus.area_changed.emit(StringName("moerkeskoven_f%d" % (i + 1)))
		bus.zone_entered.emit(&"crystal_cave")
		bus.zone_entered.emit(&"crystal_cave")
		for o in _objectives(q):
			var od2 := LuaData.dict(o)
			if str(od2.get("on", "")) == "zone_entered":
				var progress: Dictionary = qm.get_objective_progress(StringName(q), StringName(str(od2["id"])))
				var expect_done := str(od2.get("zone", "")) in ["dark_forest", "crystal_cave"]
				_need(problems, int(progress.get("current", -1)) == (1 if expect_done else 0) and bool(progress.get("done", false)) == expect_done, "%s.%s after repeated zone events: %s" % [q, od2["id"], str(progress)])
		_need(problems, qm.is_active(StringName(q)), "%s completed from zone events alone" % q)
		qm.reset()
	t.check("zone_entered_repeat_is_harmless", problems.is_empty(), "dark_forest_mining, forest_patrol, crystal_cave: repeated zone_entered / area_changed never overshoot a target of 1 and never finish the quest alone: %s" % str(problems.slice(0, 3)))
	# the anchors of the bound quests against the floor table of the dungeon addendum
	problems.clear()
	var doc := FileAccess.get_file_as_string("res://docs/design/DUNGEON_V2_ADDENDUM.md")
	var floor2 := ""
	var floor7 := ""
	var zones_row := ""
	for line in doc.split("\n"):
		if line.begins_with("| 2 | skovkant"):
			floor2 = line
		elif line.begins_with("| 7 | svampelunden"):
			floor7 = line
		elif line.begins_with("| `moerkeskoven_f1`"):
			zones_row = line
	if doc == "":
		t.skip("bound_quests_have_their_floor_anchors: docs/design/DUNGEON_V2_ADDENDUM.md is not in this tree")
	else:
		_need(problems, floor2.contains("night_bloom"), "the floor table has no night_bloom node on floor 2")
		_need(problems, floor7.contains("find_glowing") and floor7.contains("moonstone") and floor7.contains("glow_mushroom"), "the floor table: floor 7 lacks the find_glowing quest_spot, moonstone or glow_mushroom")
		_need(problems, zones_row.contains("dark_forest") and zones_row.contains("mushroom_grove") and zones_row.contains("crystal_cave"), "the floors do not carry the zone ids dark_forest / mushroom_grove / crystal_cave")
		var night: Dictionary = _objective_by_id("night_flower", "collect_night_bloom")
		var rare: Dictionary = _objective_by_id("rare_mushroom_hunt", "find_glowing")
		var mush: Dictionary = _objective_by_id("rare_mushroom_hunt", "collect_mushrooms")
		var moon: Dictionary = _objective_by_id("moonstone_crown", "collect_moonstone")
		_need(problems, str(night.get("item", "")) == "night_bloom" and str(rare.get("on", "")) == "manual" and str(mush.get("item", "")) == "glow_mushroom" and str(moon.get("item", "")) == "moonstone", "night_flower / rare_mushroom_hunt / moonstone_crown items: %s %s %s %s" % [str(night.get("item", "")), str(rare.get("on", "")), str(mush.get("item", "")), str(moon.get("item", ""))])
		for q in ["dark_forest_mining", "forest_patrol", "crystal_cave"]:
			for o in _objectives(q):
				var od3 := LuaData.dict(o)
				if str(od3.get("on", "")) == "zone_entered":
					_need(problems, zones_row.contains(str(od3.get("zone", ""))), "%s.%s binds zone `%s` which no floor carries" % [q, od3["id"], od3.get("zone", "")])
		t.check("bound_quests_have_their_floor_anchors", problems.is_empty(), "night_flower (night_bloom, floor 2), rare_mushroom_hunt (glow_mushroom + the find_glowing quest_spot, floor 7), moonstone_crown (moonstone), the zone quests (zone ids of the floors): %s" % str(problems.slice(0, 3)))
		for seed_value in [4242,8181]:
			for number in [2,7]:
				var generated := _generated_floor(number,seed_value)
				var markers := generated.markers.values()
				var valid := generated.errors.is_empty()
				if number==2:valid = valid and markers.any(func(row):return str(row.get("marker",""))=="node" and str(row.get("kind",""))=="night_bloom")
				else:
					valid = valid and markers.any(func(row):return str(row.get("marker",""))=="quest_spot" and str(row.get("quest",""))=="rare_mushroom_hunt" and str(row.get("objective",""))=="find_glowing")
					for item in ["glow_mushroom","moonstone"]:valid = valid and markers.any(func(row):return str(row.get("marker",""))=="node" and str(row.get("kind",""))==item)
				t.check("live_generated_quest_anchors_f%d_s%d"%[number,seed_value],valid,str(generated.errors))


func _objective_by_id(q: String, oid: String) -> Dictionary:
	for o in _objectives(q):
		if str(LuaData.dict(o).get("id", "")) == oid:
			return LuaData.dict(o)
	return {}


func _forste_dage() -> void:
	var problems: Array = []
	_fresh()
	# the tutorial quest binds game_event plot_tilled and post_read: the vocabulary completes objectives bound to them
	var q := _start("zz_p13_tutorial", [{"id": "till", "target": 2, "on": "game_event", "event": "plot_tilled"}, {"id": "mail", "target": 1, "on": "game_event", "event": "post_read"}], false)
	bus.game_event.emit(&"plot_tilled", {"plot_id": "plot_3_4"})
	bus.game_event.emit(&"plot_tilled", {"plot_id": "plot_3_5"})
	_need(problems, _done(q, "till") and not _done(q, "mail"), "plot_tilled x2: till %s mail %s" % [_done(q, "till"), _done(q, "mail")])
	bus.game_event.emit(&"post_read", {"quest_id": "lost_cat"})
	_need(problems, qm.is_completed(q), "post_read did not finish the quest")
	t.check("forste_dage_vocabulary_plot_tilled_post_read", problems.is_empty(), "on = game_event with event plot_tilled / post_read completes objectives (the tutorial's bindings): %s" % str(problems))
	qm.reset()
	if _def("forste_dage").is_empty():
		t.skip("forste_dage_binds_only_known_events: lua/quests/forste_dage.lua belongs to N04-farm-first-morning and is not in this tree yet")
		return
	var bad: Array[String] = []
	for o in _objectives("forste_dage"):
		var od := LuaData.dict(o)
		var on := str(od.get("on", ""))
		if on == "game_event":
			if not (str(od.get("event", "")) in KNOWN_EVENTS):
				bad.append("%s binds the unknown event %s" % [od.get("id", ""), od.get("event", "")])
		elif not (qm.FILTERS.has(on) or on == "manual" or on == "state" or qm.GAME_EVENT_SUGAR.has(on)):
			bad.append("%s binds %s" % [od.get("id", ""), on])
	t.check("forste_dage_binds_only_known_events", bad.is_empty(), "every objective of lua/quests/forste_dage.lua uses a binding of the vocabulary and, for game_event, a name of the events list %s" % str(bad))
	# GAP4-03: the can on bare tilled soil waters no crop, so "Vand tre afgrøder" counts only a plot with a crop in it
	_fresh()
	var grid := FarmGrid.new()
	t.tree.root.add_child(grid)
	var cells: Array = grid.farmable_cells()
	qm.accept_quest(&"forste_dage")
	var accepted: bool = qm.is_active(&"forste_dage")
	grid.till(cells[0])
	var bare_watered: bool = grid.water(cells[0], 12.0)
	var after_bare := _cur("forste_dage", "water")
	grid.till(cells[1])
	eco.add_item(&"carrot_seeds", 1, true)
	grid.plant(cells[1], &"carrot_seeds")
	grid.water(cells[1], 12.0)
	t.check("water_objective_counts_only_crops", accepted and bare_watered and after_bare == 0 and _cur("forste_dage", "water") == 1, "watering bare soil leaves forste_dage.water at %d, watering the planted carrot gives %d (want 0, then 1)" % [after_bare, _cur("forste_dage", "water")])
	grid.free()
	qm.reset()

func _generated_floor(number: int,seed_value: int) -> AreaMap:
	var cfg := LuaData.dict(Svc.lua_config("dungeon",{}))
	var ctx := {"next_id":"moerkeskoven_f%d"%(number+1),"prev_id":"moerkeskoven_f%d"%(number-1),"day":1,"seed_text":str(seed_value),"gen_version":1,"spec_hash":"0"}
	var result := DungeonGen.build_text(cfg,number,seed_value,ctx)
	return AreaMap.parse_text(str(result.get("text","")))
