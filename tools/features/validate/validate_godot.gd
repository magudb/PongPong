extends SceneTree
## Loads the stage tree's Lua files through the project's REAL LuaRuntime autoload (headless) and dumps what it understood.
##   godot --headless --path <project copy with the stage tree overlaid> -s validate_godot.gd -- --out=/abs/out.json --files=lua/a.lua,lua/b.lua --csvs=a.csv,b.csv
## (tools/features/validate/run_validate.sh builds the project copy; Godot never opens the repo directory itself.)
## Autoloads do not exist when this script compiles, so everything goes through root.get_node("...").
##
## The managers this driver talks to (a change there must be mirrored here, docs/features/STAGES.md lists them):
##   LuaRuntime   reload_scripts, parse_lua_source, get_config, get_item_def, get_all_script_ids, get_dialogue, _invoke_function (private, for the is_available hooks)
##   QuestManager get_quest_def, accept_quest, complete_quest, is_active, is_completed (+ active_quests / completed_quests to forget a quest between runs)
##   EconomyManager gold (or get_gold), count_item, get_inventory_dict      GameManager world_flags, set_flag, get_flag

class ErrCatcher extends Logger:
	var errors: Array[String] = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		errors.append("%s:%d in %s(): %s %s (type %d)" % [file, line, function, code, rationale, error_type])

var c := ErrCatcher.new()
var out := {}


func _initialize() -> void:
	OS.add_logger(c)
	_run.call_deferred()


func _arg(name: String, default_value: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.substr(name.length() + 3)
	return default_value


## forgets a quest between two driver runs, whatever shape the quest manager keeps its state in
func _forget_quest(qm: Node, quest: String) -> void:
	for prop in ["active_quests", "completed_quests"]:
		var v: Variant = qm.get(prop)
		if v is Dictionary:
			(v as Dictionary).erase(StringName(quest))
		elif v is Array:
			(v as Array).erase(StringName(quest))


func _gold(em: Node) -> int:
	var v: Variant = em.get("gold")
	if v != null:
		return int(v)
	if em.has_method("get_gold"):
		return int(em.call("get_gold"))
	return 0


## how many of an item the player holds, wherever the economy keeps it (backpack, furniture store, wardrobe store)
func _count(em: Node, item_id: String) -> int:
	if em.has_method("count_item"):
		return int(em.call("count_item", StringName(item_id)))
	return 0


func _backpack(em: Node) -> Dictionary:
	if em.has_method("get_inventory_dict"):
		return (em.call("get_inventory_dict") as Dictionary).duplicate()
	return {}


func _dialogue_case(lr: Node, gm: Node, label: String, flags: Dictionary) -> Dictionary:
	gm.world_flags.clear()
	for k in flags:
		gm.set_flag(StringName(k), flags[k])
	var d: Dictionary = lr.get_dialogue("fairy_builder", {})
	var lines: Array = []
	for l in d.get("lines", []):
		lines.append(l.get("text_key", ""))
	var choices: Array = []
	for ch in d.get("choices", []):
		choices.append("%s:%s:%s" % [ch.get("id", ""), ch.get("action", ""), str(ch.get("tier", ch.get("shop_id", "")))])
	return {"label": label, "flags": flags, "speaker": d.get("speaker", ""), "lines": lines, "choices": choices}


func _offer_case(lr: Node, gm: Node, npc: String, label: String, flags: Dictionary) -> Dictionary:
	gm.world_flags.clear()
	for k in flags:
		gm.set_flag(StringName(k), flags[k])
	var d: Dictionary = lr.get_dialogue(npc, {})
	var lines: Array = []
	for l in d.get("lines", []):
		lines.append(l.get("text_key", ""))
	var accepts: Array = []
	var ids: Array = []
	for ch in d.get("choices", []):
		ids.append(ch.get("id", ""))
		if ch.get("action", "") == "quest_accept":
			accepts.append(str(ch.get("quest_id", "")))
	return {"npc": npc, "label": label, "flags": flags, "lines": lines, "accepts": accepts, "choices": ids}


func _accept_via_dialogue(lr: Node, gm: Node, qm: Node, npc: String, flags: Dictionary, quest: String) -> Dictionary:
	## what Npc2D.handle_choice does for action == quest_accept: find the choice in the dialogue the player really sees and accept its quest_id
	gm.world_flags.clear()
	_forget_quest(qm, quest)
	for k in flags:
		gm.set_flag(StringName(k), flags[k])
	var d: Dictionary = lr.get_dialogue(npc, {})
	var found := ""
	for ch in d.get("choices", []):
		if ch.get("action", "") == "quest_accept" and str(ch.get("quest_id", "")) == quest:
			found = str(ch.get("id", ""))
			var ok: bool = qm.accept_quest(StringName(quest))
			return {"npc": npc, "quest": quest, "choice": found, "accepted": ok, "active": qm.is_active(StringName(quest)), "active_flag": gm.get_flag(StringName(quest + "_active"), false)}
	return {"npc": npc, "quest": quest, "choice": "", "accepted": false, "active": false, "active_flag": false}


func _run() -> void:
	await process_frame
	await process_frame
	var lr: Node = root.get_node("LuaRuntime")
	var gm: Node = root.get_node("GameManager")
	var qm: Node = root.get_node("QuestManager")
	var files: PackedStringArray = _arg("files").split(",", false)
	c.errors.clear()
	var t0 := Time.get_ticks_msec()
	lr.reload_scripts()                                   # full real load of every res://lua/** file, new ones included
	out["reload_ms"] = Time.get_ticks_msec() - t0
	out["load_errors"] = c.errors.duplicate()
	out["script_count"] = lr.get_all_script_ids().size()
	var per_file := {}
	var all_item_ids: Array = []
	for rel in files:
		var path := "res://" + rel
		var text := FileAccess.get_file_as_string(path)
		c.errors.clear()
		var tp := Time.get_ticks_msec()
		var parsed: Dictionary = lr.parse_lua_source(text, path)
		out["parse_ms_" + rel.replace("/", "_")] = Time.get_ticks_msec() - tp
		for nm in ["shops", "recipes"]:
			if not parsed.has(nm) and lr.has_method("_extract_named_table"):
				lr._extract_named_table(text, nm, parsed)
		# functions are not data; keep only their names
		var fnames: Array = []
		for k in parsed.get("functions", {}):
			fnames.append(k)
		parsed["functions"] = fnames
		parsed.erase("table_assigns")
		per_file[rel] = {"parsed": parsed, "errors": c.errors.duplicate()}
		if parsed.get("kind", "") == "items" and typeof(parsed.get("items", null)) == TYPE_DICTIONARY:
			for k in parsed["items"]:
				all_item_ids.append(k)
	out["files"] = per_file
	# the engine's own CSV reader on every new localisation file
	var csvs := {}
	for cf in _arg("csvs").split(",", false):
		var fa := FileAccess.open("res://localization/" + cf, FileAccess.READ)
		var rows := 0
		var bad := 0
		var keys := {}
		if fa:
			var header := fa.get_csv_line()
			while not fa.eof_reached():
				var line := fa.get_csv_line()
				if line.size() == 1 and line[0] == "":
					continue
				rows += 1
				if line.size() != 3 or line[1] == "" or line[2] == "":
					bad += 1
				keys[line[0]] = true
		csvs[cf] = {"rows": rows, "bad": bad, "unique": keys.size()}
	out["csv"] = csvs
	# registered item defs
	var missing_defs: Array = []
	for iid in all_item_ids:
		if lr.get_item_def(iid).is_empty():
			missing_defs.append(iid)
	out["items_declared"] = all_item_ids.size()
	out["items_missing_in_runtime"] = missing_defs
	# config reachability
	var cfg := {}
	for p in ["home.max_tier", "home.tiers", "home.hygge_levels", "rarity_tiers.order", "perk_caps.speed", "loot.containers.trae.odds", "loot.zones.skovkant.pools.furniture.normal",
			"furniture_sets.bondegaard.bonuses", "wardrobe_sets.marken.capstone", "loot.boss.snurresvamp.pool"]:
		var v: Variant = lr.get_config(p, null)
		cfg[p] = (v.size() if (typeof(v) == TYPE_ARRAY or typeof(v) == TYPE_DICTIONARY) else v)
	out["config_probe"] = cfg
	# quest registration
	var quests := {}
	for q in ["lost_cat", "fix_roof", "birthday_cake", "math_wizard_quiz", "bogtraeet", "moonstone_crown", "snurresvampen", "slotsdroemmen"]:
		var def: Dictionary = qm.get_quest_def(StringName(q))
		quests[q] = {"registered": not def.is_empty(), "reward_items": def.get("rewards", {}).get("items", {}), "gold": def.get("rewards", {}).get("gold", 0),
			"objectives": def.get("objectives", []).size(), "giver": def.get("meta", {}).get("giver", ""), "repeatable": def.get("meta", {}).get("repeatable", null)}
	out["quests"] = quests
	# end-to-end: accept + complete every quest through the real QuestManager / LuaRuntime hooks and see what lands (gold, items of ANY store, flags)
	var em: Node = root.get_node("EconomyManager")
	var e2e := {}
	var flag_names := {"lost_cat": "lost_cat_active", "fix_roof": "", "birthday_cake": "birthday_cake_active", "math_wizard_quiz": "math_quiz_active", "bogtraeet": "bogtraeet_active",
		"moonstone_crown": "moonstone_crown_active", "snurresvampen": "snurresvampen_active", "slotsdroemmen": "slotsdroemmen_active"}
	var done_names := {"lost_cat": "lost_cat_active", "fix_roof": "maja_roof_fixed", "birthday_cake": "maja_birthday_done", "math_wizard_quiz": "math_quiz_done", "bogtraeet": "bogtraeet_done",
		"moonstone_crown": "moonstone_crown_done", "snurresvampen": "snurresvampen_done", "slotsdroemmen": "slotsdroemmen_done"}
	for q in flag_names:
		c.errors.clear()
		gm.world_flags.clear()
		if q == "bogtraeet":
			for flag in ["math_bakery_done", "math_harvest_done", "math_quiz_done"]:
				gm.set_flag(StringName(flag), true)
		if q == "slotsdroemmen": gm.set_flag(&"home_tier", 10)
		_forget_quest(qm, q)
		var reward_ids: Array = []
		for rid in quests[q]["reward_items"]:
			reward_ids.append(str(rid))
		var g0: int = _gold(em)
		var have0 := {}
		for rid in reward_ids:
			have0[rid] = _count(em, rid)
		var inv0: Dictionary = _backpack(em)
		var accepted: bool = qm.accept_quest(StringName(q))
		var active_flag: Variant = gm.get_flag(StringName(flag_names[q]), false) if flag_names[q] != "" else null
		qm.complete_quest(StringName(q))
		var delta := {}
		for rid in reward_ids:
			var d: int = _count(em, rid) - int(have0[rid])
			if d != 0:
				delta[rid] = d
		var inv1: Dictionary = _backpack(em)
		var extra := {}
		for k in inv1:
			var dd: int = int(inv1[k]) - int(inv0.get(k, 0))
			if dd != 0 and not (str(k) in reward_ids):
				extra[str(k)] = dd
		e2e[q] = {"accepted": accepted, "gold_delta": _gold(em) - g0, "items": delta, "extra_items": extra, "active_flag_after_accept": active_flag, "done_flag_after_complete": gm.get_flag(StringName(done_names[q]), false),
			"completed": qm.is_completed(StringName(q)), "errors": c.errors.duplicate()}
	out["quest_e2e"] = e2e
	# builder dialogue branches (flags -> lines/choices)
	var cases: Array = []
	cases.append(_dialogue_case(lr, gm, "unset", {}))
	for t in range(1, 11):
		cases.append(_dialogue_case(lr, gm, "idle_%d" % t, {"home_tier": t}))
	for t in range(2, 11):
		cases.append(_dialogue_case(lr, gm, "building_%d" % t, {"home_tier": t - 1, "home_building": t}))
	for t in range(2, 11):
		cases.append(_dialogue_case(lr, gm, "done_%d" % t, {"home_tier": t, "home_upgrade_done": t}))
	out["builder_dialogue"] = cases
	var sk: Array = []
	for npc in ["fairy_furnisher", "fairy_tailor"]:
		var d: Dictionary = lr.get_dialogue(npc, {})
		var acts: Array = []
		for ch in d.get("choices", []):
			acts.append("%s:%s" % [ch.get("action", ""), ch.get("shop_id", "")])
		sk.append({"npc": npc, "lines": d.get("lines", []).size(), "actions": acts})
	out["shopkeepers"] = sk
	# availability hook of slotsdroemmen with / without the flag
	gm.world_flags.clear()
	out["is_available_slotsdroemmen_unset"] = lr._invoke_function("quests/slotsdroemmen", "is_available", [{}])
	gm.set_flag(&"home_tier", 10)
	out["is_available_slotsdroemmen_t10"] = lr._invoke_function("quests/slotsdroemmen", "is_available", [{}])
	gm.world_flags.clear()
	out["is_available_bogtraeet_unset"] = lr._invoke_function("quests/bogtraeet", "is_available", [{}])
	for f in ["math_bakery_done", "math_harvest_done", "math_quiz_done"]:
		gm.set_flag(StringName(f), true)
	out["is_available_bogtraeet_all_done"] = lr._invoke_function("quests/bogtraeet", "is_available", [{}])
	# REVIEW FIX (critics: plan-consistency 1, coverage 1): the four feature quests must be ACCEPTABLE by talking to someone
	var offers: Array = []
	offers.append(_offer_case(lr, gm, "guard_oak", "oak_unset", {}))
	offers.append(_offer_case(lr, gm, "guard_oak", "oak_active", {"snurresvampen_active": true}))
	offers.append(_offer_case(lr, gm, "guard_oak", "oak_done", {"snurresvampen_done": true}))
	var math_all := {"math_bakery_done": true, "math_harvest_done": true, "math_quiz_done": true}
	offers.append(_offer_case(lr, gm, "fairy_wizard", "wiz_unset", {}))
	offers.append(_offer_case(lr, gm, "fairy_wizard", "wiz_math_all", math_all))
	offers.append(_offer_case(lr, gm, "fairy_wizard", "wiz_active", {"bogtraeet_active": true}))
	var wd := math_all.duplicate()
	wd["bogtraeet_done"] = true
	offers.append(_offer_case(lr, gm, "fairy_wizard", "wiz_done", wd))
	offers.append(_offer_case(lr, gm, "fairy_king", "king_unset", {}))
	offers.append(_offer_case(lr, gm, "fairy_king", "king_tier10", {"home_tier": 10, "moonstone_crown_done": true}))
	offers.append(_offer_case(lr, gm, "fairy_king", "king_tier10_active", {"home_tier": 10, "moonstone_crown_done": true, "slotsdroemmen_active": true}))
	offers.append(_offer_case(lr, gm, "fairy_king", "king_tier10_done", {"home_tier": 10, "moonstone_crown_done": true, "slotsdroemmen_done": true}))
	offers.append(_offer_case(lr, gm, "fairy_king", "king_moon_active", {"moonstone_crown_active": true}))
	offers.append(_offer_case(lr, gm, "fairy_king", "king_moon_done_tier5", {"home_tier": 5, "moonstone_crown_done": true}))
	out["dialogue_offers"] = offers
	var via: Array = []
	via.append(_accept_via_dialogue(lr, gm, qm, "guard_oak", {}, "snurresvampen"))
	via.append(_accept_via_dialogue(lr, gm, qm, "fairy_wizard", math_all, "bogtraeet"))
	via.append(_accept_via_dialogue(lr, gm, qm, "fairy_king", {}, "moonstone_crown"))
	via.append(_accept_via_dialogue(lr, gm, qm, "fairy_king", {"home_tier": 10, "moonstone_crown_done": true}, "slotsdroemmen"))
	out["accept_via_dialogue"] = via
	gm.world_flags.clear()
	out["runtime_errors_after"] = c.errors.duplicate()
	var fh := FileAccess.open(_arg("out", "/tmp/validate_godot.json"), FileAccess.WRITE)
	fh.store_string(JSON.stringify(out, "  "))
	fh.close()
	print("validate_godot: wrote ", _arg("out"))
	quit()
