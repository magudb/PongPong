extends RefCounted
## Section core (package P02): the EventBus signal contract, GameManager (phases and modal stack, new game, flags, zones,
## clock and calendar, save dictionary) and TimeManager (calendar names, weather, ticking).
##
## Named checks (plan 8.2 / 8.5 / addendum 4.4): core.modal_stack, core.new_game_resets_all, core.calendar_names,
## core.advance_time_multiday, core.unlock_zone_signals, core.signal_arity_lint (covers the 14 feature signals),
## core.flag_int_after_json_roundtrip.
##
## The section is a sandbox: it leaves the world scene, drives the autoloads synchronously (no frame passes between a
## state change and its assertion, so the real-time clock cannot interfere) and ends in a fresh MENU state.
## The real da/en copy of the calendar keys lives in ui.csv (P07) and the runtime loader in P03: this section injects a
## temporary Translation with the canonical texts (plan 3.4); hud.date_text_real_keys (P17) asserts the real ones.
const SECTION := "core"
const TIMEOUT_S := 90.0

# ---------------------------------------------------------------- fixtures (canonical copy of plan 3.4, test input only)

const DA_WEEKDAYS: Array[String] = ["Mandag", "Tirsdag", "Onsdag", "Torsdag", "Fredag", "Lørdag", "Søndag"]
const EN_WEEKDAYS: Array[String] = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
const DA_MONTHS := {"FORAAR": "Blomstermåned", "SOMMER": "Solmåned", "EFTERAAR": "Høstmåned", "VINTER": "Frostmåned"}
const EN_MONTHS := {"FORAAR": "Month of Blooms", "SOMMER": "Month of Sun", "EFTERAAR": "Month of Harvest", "VINTER": "Month of Frost"}
const DA_WEATHER := {"KLART": "Solskin", "REGN": "Regn", "TAAGE": "Tåge", "SNE": "Sne", "TORDEN": "Torden"}
const EN_WEATHER := {"KLART": "Sunny", "REGN": "Rain", "TAAGE": "Fog", "SNE": "Snow", "TORDEN": "Thunder"}

## Signals that existed before the 2D rewrite and keep their arity (argument names and types).
## Player-scoped signals moved to MP3_SIGNALS when they gained player_id (DT-MP5).
const LEGACY_SIGNALS := {
	"day_started": "day:int,season:StringName",
	"day_ended": "day:int,season:StringName",
	"time_of_day_changed": "hour:int,minute:int",
	"season_changed": "season:StringName",
	"crop_planted": "plot_id:StringName,crop_id:StringName",
	"crop_watered": "plot_id:StringName",
	"crop_harvested": "plot_id:StringName,crop_id:StringName,amount:int",
	"crop_stage_changed": "plot_id:StringName,stage:int",
	"plot_unlocked": "plot_id:StringName",
	"shop_opened": "shop_id:StringName",
	"shop_closed": "shop_id:StringName",
	"dialogue_started": "npc_id:StringName,dialogue_id:StringName",
	"dialogue_line_shown": "speaker:String,text:String,voice_key:String",
	"dialogue_ended": "",
	"zone_entered": "zone_id:StringName",
	"zone_exited": "zone_id:StringName",
	"resource_node_hit": "node_id:StringName,node_type:StringName,damage:int",
	"resource_node_depleted": "node_id:StringName,loot:Array",
	"rare_item_found": "item_id:StringName,rarity:StringName",
	"enemy_encountered": "enemy_id:StringName",
	"combat_finished": "victory:bool",
	"notification_posted": "title:String,message:String,icon:String",
	"ui_panel_toggled": "panel_name:StringName,is_open:bool",
	"save_completed": "slot:int",
	"load_completed": "slot:int",
	"lua_event": "event_name:StringName,payload:Dictionary",
}

## PLAN 3.5: the retyped signal, the new signals and R.13 (hotbar_assign_requested, game_event).
## Player-scoped signals moved to MP3_SIGNALS when they gained player_id (DT-MP5).
const PLAN_SIGNALS := {
	"player_spawned": "player:Node2D",
	"new_game_started": "",
	"zone_unlocked": "zone_id:StringName",
	"recipe_crafted": "recipe_id:StringName,amount:int",
	"building_built": "building_id:StringName,building_type:StringName",
	"animal_adopted": "animal_id:StringName,species:StringName",
	"animal_fed": "animal_id:StringName,food_id:StringName",
	"animal_product_collected": "animal_id:StringName,product_id:StringName,amount:int",
	"area_change_requested": "area_id:StringName,spawn_name:StringName",
	"area_changed": "area_id:StringName",
	"boss_bar_changed": "name_key:String,ratio:float,visible:bool",
	"whisper_requested": "text_key:String",
	"weather_changed": "weather:StringName",
	"enemy_defeated": "enemy_id:StringName,kind:StringName,loot:Array",
	"modal_changed": "stack:Array",
	"game_event": "name:StringName,payload:Dictionary",
}

## Addendum 3.1: the 14 feature signals, exact arities.
## Player-scoped ones moved to MP3_SIGNALS when they gained player_id (DT-MP5).
const FEATURE_SIGNALS := {
	"home_upgrade_started": "from_tier:int,to_tier:int,ready_total_day:int",
	"home_upgrade_progress": "days_left:int,total_days:int",
	"home_upgraded": "old_tier:int,new_tier:int",
	"hygge_changed": "score:int,level:StringName",
	"furniture_changed": "reason:StringName",
	"furniture_placed": "item_id:StringName,uid:int",
	"furniture_picked_up": "item_id:StringName,uid:int",
	"decorate_mode_changed": "active:bool",
	"loot_rolled": "source_id:StringName,results:Array",
	"visitor_gift": "npc_id:StringName,item_id:StringName",
	"item_discovered": "item_id:StringName,rarity:StringName,category:StringName",
}

## The devin-review fix round: flags are event-driven (IsoArea used to poll them at 4 Hz). The 2026-10-19 review: a Lua reload
## (F9) tells the systems that copied Lua data (LUA-03).
const REVIEW_SIGNALS := {
	"flag_changed": "flag:StringName,value:Nil",
	"save_failed": "slot:int,code:String",
	"crop_auto_watered": "plot_id:StringName,source:StringName",
	"lua_reloaded": "",
}

## Multiplayer track: player registry + the MP3 player_id cut (DT-MP5) + session signals for MP4.
const MULTIPLAYER_SIGNALS := {
	"player_despawned": "player_id:StringName",
	"player_joined": "player_id:StringName,peer_id:int,profile:Dictionary",
	"player_left": "player_id:StringName,reason:StringName",
	"net_session_changed": "state:StringName",
	"player_character_changed": "player_id:StringName,character_id:StringName",
	"player_inventory_changed": "player_id:StringName,inventory:Dictionary",
	"player_stats_changed": "player_id:StringName,stats:Dictionary",
	"player_moved": "player_id:StringName,zone:StringName",
	"player_health_changed": "player_id:StringName,half_hearts:int,max_half_hearts:int",
	"player_oil_changed": "player_id:StringName,seconds:float,max_seconds:float",
	"player_defeated": "player_id:StringName",
	"hotbar_changed": "player_id:StringName,entries:Array,selected:int",
	"hotbar_assign_requested": "player_id:StringName,slot:int,item_id:StringName",
	"interaction_prompt_changed": "player_id:StringName,text:String",
	"gold_changed": "player_id:StringName,amount:int,delta:int",
	"item_gained": "player_id:StringName,item_id:StringName,amount:int",
	"item_purchased": "player_id:StringName,item_id:StringName,amount:int,cost:int",
	"item_sold": "player_id:StringName,item_id:StringName,amount:int,revenue:int",
	"quest_offered": "player_id:StringName,quest_id:StringName",
	"quest_accepted": "player_id:StringName,quest_id:StringName",
	"quest_objective_updated": "player_id:StringName,quest_id:StringName,objective_id:StringName,progress:int,target:int",
	"quest_completed": "player_id:StringName,quest_id:StringName",
	"quest_failed": "player_id:StringName,quest_id:StringName",
	"outfit_changed": "player_id:StringName,equipped:Dictionary",
	"garment_equipped": "player_id:StringName,item_id:StringName,slot:StringName",
	"friend_changed": "player_id:StringName,npc_id:StringName,hearts:int",
}

var t
var gm: Node
var tm: Node
var bus: Node
var PH: Dictionary = {}


func run(p_t) -> void:
	t = p_t
	gm = t.autoload("GameManager")
	tm = t.autoload("TimeManager")
	bus = t.autoload("EventBus")
	if gm == null or tm == null or bus == null:
		return
	PH = gm.GamePhase
	var locale_before := TranslationServer.get_locale()
	# a clean sandbox: no world scene, only the autoloads
	await t.go_menu()
	gm.clear_config_overrides()

	_test_signal_contract()
	_test_signal_lint()
	_test_config_single_source()
	_test_modal_stack()
	_test_flags()
	_test_new_game()
	_test_from_dict()
	_test_unlock_zone()
	_test_clock()
	_test_total_day()
	_test_sleep_helper()
	_test_calendar_names()
	_test_weather()
	_test_time_ticking()
	_test_no_mouse_capture()

	# leave a fresh MENU state behind
	gm.clear_config_overrides()
	gm.pop_all_modals()
	TranslationServer.set_locale(locale_before)
	gm.start_new_game("Tester", gm.CharacterType.ANIMAL, "Testgaarden")
	gm.change_phase(PH.MENU)


# ================================================================ EventBus: declarations and project-wide lint

func _test_signal_contract() -> void:
	var declared := _declared_signals()
	var all_contract := _contract()
	var missing: Array[String] = []
	var wrong: Array[String] = []
	var undeclared: Array[String] = []
	for sig_name in all_contract:
		if not declared.has(sig_name):
			missing.append(sig_name)
		elif declared[sig_name] != all_contract[sig_name]:
			wrong.append("%s has (%s) want (%s)" % [sig_name, declared[sig_name], all_contract[sig_name]])
	for sig_name in declared:
		if not all_contract.has(sig_name):
			undeclared.append(sig_name)
	t.check("signal_contract_exact", missing.is_empty() and wrong.is_empty() and undeclared.is_empty(),
		"%d signals; missing %s, wrong %s, not in the contract %s" % [declared.size(), missing, wrong, undeclared])
	t.check("legacy_signals_keep_arity", _subset_matches(declared, LEGACY_SIGNALS), "%d legacy signals" % LEGACY_SIGNALS.size())
	t.check("plan_3_5_signals", _subset_matches(declared, PLAN_SIGNALS), "%d signals of PLAN 3.5 + R.13" % PLAN_SIGNALS.size())
	t.check("feature_signals_14", FEATURE_SIGNALS.size() == 11 and _subset_matches(declared, FEATURE_SIGNALS), "addendum 3.1 (outfit/garment/friend moved to MP3_SIGNALS)")
	t.check("mp3_signals_exact", _subset_matches(declared, MULTIPLAYER_SIGNALS) and MULTIPLAYER_SIGNALS.size() >= 4, "player registry + player_id cut")
	t.check("review_fix_signals", _subset_matches(declared, REVIEW_SIGNALS), "devin-review additions (flag_changed)")
	t.check("farm_upgraded_removed", not declared.has("farm_upgraded"), "PLAN 3.5: removed, never used")
	t.check("r13_escape_hatch_and_hotbar_assign", declared.get("game_event", "") == "name:StringName,payload:Dictionary" and declared.get("hotbar_assign_requested", "") == "player_id:StringName,slot:int,item_id:StringName", "R.13")
	# player_spawned takes a Node2D in the 2D game
	var got: Array = []
	var cb := func(p) -> void: got.append(p is Node2D)
	bus.player_spawned.connect(cb)
	var probe := Node2D.new()
	bus.player_spawned.emit(probe)
	bus.player_spawned.disconnect(cb)
	probe.free()
	t.check("player_spawned_node2d", got == [true], "emitted with a Node2D")


func _test_signal_lint() -> void:
	var sigs := {}
	for info in bus.get_script().get_script_signal_list():
		sigs[str(info["name"])] = (info["args"] as Array).size()
	var members := _bus_members()
	var files := _gd_files(["res://scripts", "res://scenes", "res://tests/sections"])
	var violations: Array = []
	var uses := 0
	for path in files:
		if path == "res://tests/sections/core.gd":
			continue
		var text := FileAccess.get_file_as_string(path)
		if not text.contains("EventBus"):
			continue
		var result := _lint_text(path, text, sigs, members)
		uses += int(result["uses"])
		violations.append_array(result["violations"])
	var feature_ok := true
	for sig_name in FEATURE_SIGNALS:
		var want_arity := 0 if FEATURE_SIGNALS[sig_name] == "" else str(FEATURE_SIGNALS[sig_name]).count(",") + 1
		feature_ok = feature_ok and sigs.get(sig_name, -1) == want_arity
	t.check("signal_arity_lint", violations.is_empty(), "%d EventBus uses in %d files, %d violation(s) %s; covers %d feature signals" % [
		uses, files.size(), violations.size(), violations.slice(0, 3), FEATURE_SIGNALS.size()])
	t.check("signal_arity_lint_covers_14_feature_signals", feature_ok and FEATURE_SIGNALS.size() == 11, "arity of every addendum 3.1 signal")
	# the lint itself must see mistakes (a lint that scans nothing would stay green forever)
	var bad := "EventBus.gold_changed.emit(5)\nEventBus.nope.emit()\nEventBus.day_started.connect(func(a): pass)\nEventBus.home_upgraded.connect(_h)\nfunc _h(a, b, c):\n\tpass\nEventBus.save_completed.connect(_t2)\nfunc _t2():\n\tpass\nEventBus.item_sold.emit(\n\t&\"p0\", &\"x\", clampi(1, 0, 5)\n)\nMyEventBus.nope.emit()\n"
	var bad_result := _lint_text("sample", bad, sigs, members)
	var good := "EventBus.gold_changed.emit(&\"p0\", 5, 1) # EventBus.nope.emit()\nEventBus.home_upgraded.connect(_h)\nvar s := \"EventBus.nope.emit()\"\nEventBus.day_started.connect(func(_a, _b): pass)\nfunc _h(a, b):\n\tpass\nEventBus.item_purchased.emit(\n\t&\"p0\", &\"x\", clampi(1, 0, 5), int(Vector2(1, 2).x)\n)\nEventBus.quest_objective_updated.connect(func(_p: StringName, _q: StringName, _o: StringName, _pr: int, _t: int = 0) -> void: pass)\nEventBus.save_completed.connect(_s2, CONNECT_ONE_SHOT)\nfunc _s2(slot: int = 0):\n\tpass\nEventBus.load_completed.connect(_inherited)\nEventBus.shop_opened.connect(_on_x.bind(1))\n"
	var good_result := _lint_text("sample", good, sigs, members)
	t.check("signal_arity_lint_detects_mismatch", (bad_result["violations"] as Array).size() == 6 and (good_result["violations"] as Array).is_empty(),
		"bad sample %s, good sample %s" % [bad_result["violations"], good_result["violations"]])


func _contract() -> Dictionary:
	var all_contract := {}
	all_contract.merge(LEGACY_SIGNALS)
	all_contract.merge(PLAN_SIGNALS)
	all_contract.merge(FEATURE_SIGNALS)
	all_contract.merge(REVIEW_SIGNALS)
	all_contract.merge(MULTIPLAYER_SIGNALS)
	return all_contract


func _declared_signals() -> Dictionary:
	var out := {}
	for info in bus.get_script().get_script_signal_list():
		var parts: Array[String] = []
		for a in info["args"]:
			var type_text := ""
			if int(a["type"]) == TYPE_OBJECT and str(a["class_name"]) != "":
				type_text = str(a["class_name"])
			else:
				type_text = type_string(int(a["type"]))
			parts.append("%s:%s" % [a["name"], type_text])
		out[str(info["name"])] = ",".join(parts)
	return out


func _subset_matches(declared: Dictionary, wanted: Dictionary) -> bool:
	for sig_name in wanted:
		if declared.get(sig_name, "<missing>") != wanted[sig_name]:
			return false
	return true


func _bus_members() -> Dictionary:
	var out := {}
	for m in bus.get_method_list():
		out[str(m["name"])] = true
	for p in bus.get_property_list():
		out[str(p["name"])] = true
	return out


func _gd_files(roots: Array) -> Array[String]:
	var out: Array[String] = []
	for root_path in roots:
		_collect_gd(str(root_path), out)
	out.sort()
	return out


func _collect_gd(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if not sub.begins_with("."):
			_collect_gd(dir_path.path_join(sub), out)
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))


## Checks every `EventBus.<name>` of a script: the name must be a declared signal or a member of the node, and
## `.emit(...)` / `.connect(handler)` must match the arity of the signal. Handlers that cannot be resolved statically
## (inherited methods, Callable(...), bind/unbind) are skipped, never guessed.
func _lint_text(path: String, text: String, sigs: Dictionary, members: Dictionary) -> Dictionary:
	var src := _blank_strings_and_comments(text)
	var out: Array = []
	var uses := 0
	var rx := RegEx.new()
	rx.compile("\\bEventBus\\.([A-Za-z_][A-Za-z0-9_]*)")
	var call_rx := RegEx.new()
	call_rx.compile("^\\s*\\.\\s*(emit|connect)\\s*\\(")
	for m in rx.search_all(src):
		var ident := m.get_string(1)
		var after := m.get_end()
		var line := 1 + src.substr(0, m.get_start()).count("\n")
		uses += 1
		if not sigs.has(ident):
			if not members.has(ident):
				out.append("%s:%d EventBus.%s is neither a declared signal nor a member" % [path, line, ident])
			continue
		var arity: int = sigs[ident]
		var tail := src.substr(after, 48)
		var cm := call_rx.search(tail)
		if cm == null:
			continue
		var open_idx := after + cm.get_end() - 1
		var close_idx := _matching_paren(src, open_idx)
		if close_idx < 0:
			continue
		var inner := src.substr(open_idx + 1, close_idx - open_idx - 1)
		var parts := _split_top(inner)
		if cm.get_string(1) == "emit":
			if parts.size() != arity:
				out.append("%s:%d EventBus.%s.emit() has %d argument(s), the signal has %d" % [path, line, ident, parts.size(), arity])
			continue
		if parts.is_empty():
			continue
		var range_v := _handler_arity_range(parts[0].strip_edges(), src)
		if range_v.x >= 0 and (arity < range_v.x or arity > range_v.y):
			out.append("%s:%d EventBus.%s.connect(%s) accepts %d..%d argument(s), the signal passes %d" % [path, line, ident, parts[0].strip_edges().left(40), range_v.x, range_v.y, arity])
	return {"violations": out, "uses": uses}


## (min, max) argument count of a connect() handler expression, or (-1, -1) when it cannot be decided statically.
func _handler_arity_range(expr: String, src: String) -> Vector2i:
	if expr.begins_with("func"):
		var open_idx := expr.find("(")
		if open_idx < 0 or expr.substr(4, open_idx - 4).strip_edges() != "":
			return Vector2i(-1, -1)
		var close_idx := _matching_paren(expr, open_idx)
		if close_idx < 0:
			return Vector2i(-1, -1)
		return _param_range(expr.substr(open_idx + 1, close_idx - open_idx - 1))
	var ident_rx := RegEx.new()
	ident_rx.compile("^[A-Za-z_][A-Za-z0-9_]*$")
	if ident_rx.search(expr) == null:
		return Vector2i(-1, -1)
	var def_rx := RegEx.new()
	def_rx.compile("(?m)^[ \\t]*(?:static[ \\t]+)?func[ \\t]+" + expr + "[ \\t]*\\(")
	var defs := def_rx.search_all(src)
	if defs.size() != 1:
		return Vector2i(-1, -1)
	var open_def := defs[0].get_end() - 1
	var close_def := _matching_paren(src, open_def)
	if close_def < 0:
		return Vector2i(-1, -1)
	return _param_range(src.substr(open_def + 1, close_def - open_def - 1))


func _param_range(param_text: String) -> Vector2i:
	var parts := _split_top(param_text)
	var required := 0
	for p in parts:
		if not p.contains("="):
			required += 1
	return Vector2i(required, parts.size())


## Replaces the inside of string literals and comments with spaces (offsets and line numbers stay valid).
func _blank_strings_and_comments(text: String) -> String:
	var out := PackedStringArray()
	var quote := ""
	var in_comment := false
	var i := 0
	var n := text.length()
	while i < n:
		var ch := text[i]
		if in_comment:
			if ch == "\n":
				in_comment = false
				out.append(ch)
			else:
				out.append(" ")
		elif quote != "":
			if ch == "\\" and i + 1 < n:
				out.append("  ")
				i += 1
			elif ch == quote:
				quote = ""
				out.append(ch)
			elif ch == "\n":
				out.append(ch)
			else:
				out.append(" ")
		elif ch == "\"" or ch == "'":
			quote = ch
			out.append(ch)
		elif ch == "#":
			in_comment = true
			out.append(" ")
		else:
			out.append(ch)
		i += 1
	return "".join(out)


func _matching_paren(src: String, open_idx: int) -> int:
	var depth := 0
	for i in range(open_idx, src.length()):
		var ch := src[i]
		if ch == "(":
			depth += 1
		elif ch == ")":
			depth -= 1
			if depth == 0:
				return i
	return -1


func _split_top(text: String) -> Array[String]:
	var parts: Array[String] = []
	if text.strip_edges() == "":
		return parts
	var depth := 0
	var start := 0
	for i in text.length():
		var ch := text[i]
		if ch == "(" or ch == "[" or ch == "{":
			depth += 1
		elif ch == ")" or ch == "]" or ch == "}":
			depth -= 1
		elif ch == "," and depth == 0:
			parts.append(text.substr(start, i - start))
			start = i + 1
	parts.append(text.substr(start))
	return parts


# ================================================================ configuration: one source of truth

func _test_config_single_source() -> void:
	gm.clear_config_overrides()
	t.check("config_literal_defaults", gm.DEFAULT_DAYS_PER_SEASON == 28 and gm.DEFAULT_SEASONS == [&"foraar", &"sommer", &"efteraar", &"vinter"]
		and gm.DEFAULT_DAY_START_HOUR == 6 and gm.DEFAULT_DAY_END_HOUR == 26 and gm.DEFAULT_MINUTES_PER_REAL_SECOND == 2.0, "28 days, 4 seasons, 06:00 to 26:00 (= 02:00 at night), 2 min/s")
	var lua: Node = bus.get_node_or_null("/root/LuaRuntime")
	var want_mps := 2.0
	if lua != null:
		want_mps = float(lua.get_config("time.minutes_per_real_second", 2.0))
	t.check("config_read_from_lua", is_equal_approx(gm.minutes_per_real_second(), want_mps) and gm.days_per_season() >= 1 and gm.seasons().size() >= 1,
		"minutes_per_real_second %s from LuaRuntime time.*" % gm.minutes_per_real_second())
	t.check("time_manager_has_no_second_copy", not _const_names(tm).has("DAYS_PER_SEASON") and not _const_names(tm).has("SEASONS") and not _const_names(tm).has("MINUTES_PER_REAL_SECOND"),
		"TimeManager delegates to GameManager")
	# overrides prove that the calendar really follows the config: 7-day seasons, two seasons
	gm.set_config_override("time.days_per_season", 7)
	gm.set_config_override("time.seasons", ["aa", "bb"])
	t.check("config_override_seasons", gm.days_per_season() == 7 and gm.seasons() == [&"aa", &"bb"], "override seam")
	_set_clock(7, &"aa", 1, 23, 0)
	gm.end_day()
	t.check("config_drives_end_day", gm.day == 1 and gm.season == &"bb" and gm.year == 1, "day 7 of aa -> day 1 of bb (%d %s)" % [gm.day, gm.season])
	_set_clock(7, &"bb", 1, 23, 0)
	gm.end_day()
	t.check("config_drives_year", gm.day == 1 and gm.season == &"aa" and gm.year == 2 and gm.total_day() == 15, "year 2 starts at total day 15 (%d)" % gm.total_day())
	gm.clear_config_overrides()


func _const_names(node: Node) -> Array:
	var names: Array = []
	var script: Script = node.get_script()
	if script != null:
		names = script.get_script_constant_map().keys()
	return names


# ================================================================ GameManager: phases and the modal stack

func _test_modal_stack() -> void:
	gm.change_phase(PH.PLAYING)
	var mouse_before := Input.mouse_mode
	var w := _watch(["modal_changed"])
	# (a) two modals: paused until the LAST pop
	gm.push_modal(&"pause")
	var paused_one: bool = t.tree.paused and gm.current_phase == PH.PAUSED
	gm.push_modal(&"settings")
	var paused_two: bool = t.tree.paused and gm.current_phase == PH.PAUSED and gm.modal_stack() == [&"pause", &"settings"]
	gm.pop_modal(&"settings")
	var still_paused: bool = t.tree.paused and gm.current_phase == PH.PAUSED and gm.is_modal_open(&"pause") and not gm.is_modal_open(&"settings")
	gm.pop_modal(&"pause")
	var resumed: bool = not t.tree.paused and gm.current_phase == PH.PLAYING and not gm.is_modal_open()
	t.check("modal_stack", paused_one and paused_two and still_paused and resumed,
		"push x2 / pop x2: paused %s %s, after first pop %s, after last pop resumed %s" % [paused_one, paused_two, still_paused, resumed])
	var stacks: Array = []
	for entry in w["log"]:
		stacks.append(entry[1][0])
	t.check("modal_changed_signal", stacks == [[&"pause"], [&"pause", &"settings"], [&"pause"], []], "modal_changed payloads %s" % [stacks])
	_unwatch(w)
	# pop order differs from push order (the audited softlock)
	gm.push_modal(&"inventory")
	gm.push_modal(&"journal")
	gm.pop_modal(&"inventory")
	var after_first: bool = t.tree.paused and gm.current_phase == PH.PAUSED and gm.modal_stack() == [&"journal"]
	gm.pop_modal(&"journal")
	t.check("modal_stack_pop_out_of_order", after_first and not t.tree.paused and gm.current_phase == PH.PLAYING, "pop the older modal first")
	# non-pausing modal (dialogue): CUTSCENE, the tree keeps running; mixed stacks restore the right phase
	gm.push_modal(&"dialogue", false)
	var cutscene: bool = gm.current_phase == PH.CUTSCENE and not t.tree.paused
	gm.push_modal(&"shop")
	var shop_over_dialogue: bool = gm.current_phase == PH.PAUSED and t.tree.paused
	gm.pop_modal(&"dialogue")
	var dialogue_gone: bool = gm.current_phase == PH.PAUSED and t.tree.paused
	gm.pop_modal(&"shop")
	var all_gone: bool = gm.current_phase == PH.PLAYING and not t.tree.paused
	gm.push_modal(&"shop")
	gm.push_modal(&"dialogue", false)
	gm.pop_modal(&"shop")
	var back_to_cutscene: bool = gm.current_phase == PH.CUTSCENE and not t.tree.paused
	gm.pop_modal(&"dialogue")
	var back_to_playing: bool = gm.current_phase == PH.PLAYING and not t.tree.paused
	t.check("modal_phase_cutscene_and_restore", cutscene and shop_over_dialogue and dialogue_gone and all_gone and back_to_cutscene and back_to_playing,
		"CUTSCENE %s, shop over dialogue %s, %s, %s, back to CUTSCENE %s, PLAYING %s" % [cutscene, shop_over_dialogue, dialogue_gone, all_gone, back_to_cutscene, back_to_playing])
	# a modal pushes once: a second push only updates, one pop closes it; unknown pops and empty names are harmless
	gm.push_modal(&"map")
	gm.push_modal(&"map")
	var single: bool = gm.modal_stack() == [&"map"]
	gm.pop_modal(&"never_opened")
	gm.pop_modal(&"map")
	t.check("modal_push_is_idempotent", single and not gm.is_modal_open() and not t.tree.paused, "double push = one entry, unknown pop ignored")
	t.allow("a modal needs a name")
	t.info("expected engine error below (declared with allow): push_modal with an empty name")
	gm.push_modal(&"")
	t.expect_allowed("a modal needs a name", 1, "empty modal name is refused with an error")
	t.check("modal_empty_name_refused", not gm.is_modal_open(), "")
	# scene boundaries: MENU / CHARACTER_SELECT drop the stack and unpause (quit to menu)
	gm.push_modal(&"pause")
	gm.push_modal(&"settings")
	gm.change_phase(PH.MENU)
	t.check("modal_stack_cleared_at_menu", not gm.is_modal_open() and not t.tree.paused and gm.current_phase == PH.MENU, "quit to menu leaves a live, unpaused menu")
	gm.push_modal(&"settings")
	var menu_modal: bool = gm.current_phase == PH.PAUSED and t.tree.paused
	gm.pop_modal(&"settings")
	t.check("modal_over_menu_restores_menu", menu_modal and gm.current_phase == PH.MENU and not t.tree.paused, "settings over the title")
	gm.change_phase(PH.CHARACTER_SELECT)
	t.check("phase_character_select", gm.current_phase == PH.CHARACTER_SELECT, "")
	# legacy panels still pause through change_phase
	gm.change_phase(PH.PAUSED)
	var legacy_paused: bool = t.tree.paused and gm.current_phase == PH.PAUSED
	gm.change_phase(PH.PLAYING)
	t.check("phase_legacy_change_phase", legacy_paused and not t.tree.paused and gm.current_phase == PH.PLAYING, "change_phase(PAUSED/PLAYING)")
	gm.push_modal(&"journal")
	gm.change_phase(PH.PLAYING)
	t.check("phase_playing_does_not_unpause_open_modal", t.tree.paused and gm.current_phase == PH.PAUSED, "an open modal wins over change_phase(PLAYING)")
	gm.pop_all_modals()
	t.check("phase_after_pop_all", not t.tree.paused and gm.current_phase == PH.PLAYING and not gm.is_modal_open(), "")
	var quiet := _watch(["modal_changed"])
	gm.change_phase(PH.MENU)
	gm.change_phase(PH.PLAYING)
	gm.pop_all_modals()
	gm.pop_modal(&"nothing")
	t.check("modal_changed_only_when_the_stack_changes", quiet["log"].is_empty(), "scene boundaries and no-op pops are silent: %s" % [quiet["log"]])
	_unwatch(quiet)
	t.check("modal_never_touches_the_mouse", Input.mouse_mode == mouse_before, "mouse mode stays %d" % mouse_before)


# ================================================================ GameManager: world flags

func _test_flags() -> void:
	gm.world_flags.clear()
	gm.set_flag(&"a_bool", true)
	gm.set_flag(&"an_int", 7)
	gm.set_flag(&"a_float", 1.5)
	gm.set_flag(&"a_string", "hej")
	gm.set_flag(&"a_stringname", &"skov")
	t.check("flags_json_safe_types", gm.get_flag(&"a_bool") == true and gm.get_flag(&"an_int") == 7 and gm.get_flag(&"a_float") == 1.5
		and gm.get_flag(&"a_string") == "hej" and typeof(gm.get_flag(&"a_stringname")) == TYPE_STRING, "bool, int, float, String; StringName is stored as String")
	t.allow("(use bool, int, float or String)")
	t.info("expected engine errors below (declared with allow): set_flag with an Array, a Vector2 and NAN")
	gm.set_flag(&"bad_array", [1, 2])
	gm.set_flag(&"bad_vector", Vector2(1, 2))
	gm.set_flag(&"bad_nan", NAN)
	t.expect_allowed("(use bool, int, float or String)", 3, "non JSON-safe values are refused with an error")
	t.check("flags_unsafe_values_not_stored", not gm.world_flags.has(&"bad_array") and not gm.world_flags.has(&"bad_vector") and not gm.world_flags.has(&"bad_nan"), "")
	gm.set_flag(&"a_bool", null)
	t.check("flags_null_clears", not gm.world_flags.has(&"a_bool") and gm.get_flag(&"a_bool", "gone") == "gone", "")
	gm.clear_flag(&"an_int")
	t.check("flags_clear", not gm.world_flags.has(&"an_int"), "")
	# flag_int: every number comes back from JSON as float
	gm.world_flags.clear()
	t.check("flag_int_defaults", gm.flag_int(&"home_tier", 1) == 1 and gm.flag_int(&"home_building", 0) == 0 and gm.flag_int(&"home_upgrade_done") == 0, "absent flags: home_tier 1, home_building 0, home_upgrade_done 0")
	gm.set_flag(&"x_float", 3.0)
	gm.set_flag(&"x_bool", true)
	gm.set_flag(&"x_text", "12")
	gm.set_flag(&"x_word", "tre")
	var coerced: bool = typeof(gm.flag_int(&"x_float")) == TYPE_INT and gm.flag_int(&"x_float") == 3 and gm.flag_int(&"x_bool") == 1 and gm.flag_int(&"x_text") == 12 and gm.flag_int(&"x_word", 9) == 9
	t.check("flag_int_coerces", coerced, "3.0 -> 3, true -> 1, '12' -> 12, 'tre' -> default")
	# the real path: HomeManager's flags through to_dict -> JSON -> from_dict
	gm.start_new_game("Mia", gm.CharacterType.FAIRY, "Farmen")
	gm.set_flag(gm.FLAG_HOME_TIER, 4)
	gm.set_flag(gm.FLAG_HOME_BUILDING, 5)
	gm.set_flag(gm.FLAG_HOME_UPGRADE_DONE, 228)
	var saved: Dictionary = gm.to_dict()
	var json_text := JSON.stringify(saved)
	var back: Variant = JSON.parse_string(json_text)
	gm.start_new_game("Other", gm.CharacterType.ANIMAL, "X")
	var fresh_default: bool = gm.flag_int(gm.FLAG_HOME_TIER, 1) == 1 and gm.flag_int(gm.FLAG_HOME_BUILDING, 0) == 0
	gm.from_dict(back)
	var raw_is_float: bool = typeof(gm.get_flag(gm.FLAG_HOME_TIER)) == TYPE_FLOAT
	var ints_ok: bool = typeof(gm.flag_int(gm.FLAG_HOME_TIER, 1)) == TYPE_INT and gm.flag_int(gm.FLAG_HOME_TIER, 1) == 4 \
		and gm.flag_int(gm.FLAG_HOME_BUILDING, 0) == 5 and gm.flag_int(gm.FLAG_HOME_UPGRADE_DONE, 0) == 228
	t.check("flag_int_after_json_roundtrip", fresh_default and raw_is_float and ints_ok,
		"new game defaults ok %s; raw value after JSON is a float %s; flag_int gives ints %s" % [fresh_default, raw_is_float, ints_ok])


# ================================================================ GameManager: new game

func _test_new_game() -> void:
	var w := _watch(["player_character_changed", "new_game_started", "modal_changed", "day_started", "weather_changed"])
	# dirty every part of the run first
	gm.set_flag(&"dirty_flag", true)
	gm.set_flag(gm.FLAG_INTRO_PENDING, false)
	gm.unlock_zone(&"crystal_cave")
	gm.day = 17
	gm.season = &"vinter"
	gm.year = 3
	gm.hour = 20
	gm.minute = 40
	gm.discovered_locations.append(&"somewhere")
	gm.play_time_seconds = 99.0
	gm.push_modal(&"leftover")
	tm.set_weather(&"torden")
	tm.pause_time()
	tm.time_scale = 3.0
	w["log"].clear()
	# the state the moment new_game_started fires: everything must already be reset (it is the LAST thing emitted)
	var seen := {}
	var on_new := func() -> void:
		seen["day"] = gm.day
		seen["season"] = gm.season
		seen["year"] = gm.year
		seen["hour"] = gm.hour
		seen["flags"] = gm.world_flags.duplicate()
		seen["zones"] = gm.unlocked_zones.duplicate()
		seen["modals"] = gm.modal_stack()
		seen["skin"] = gm.character_skin
		seen["phase"] = gm.current_phase
	bus.new_game_started.connect(on_new)
	gm.start_new_game("Mia", gm.CharacterType.FAIRY, "Farmen")
	bus.new_game_started.disconnect(on_new)
	var names := _names(w["log"])
	var skin_idx := names.find("player_character_changed")
	var ngs_idx := names.find("new_game_started")
	var order_ok: bool = skin_idx >= 0 and ngs_idx > skin_idx
	t.check("new_game_signal_once_and_last", names.count("new_game_started") == 1 and names.count("player_character_changed") == 1 and order_ok and not names.has("day_started"),
		"signals in order: %s" % [names])
	var after_ngs: Array = names.slice(names.find("new_game_started") + 1)
	t.check("new_game_started_is_last_gm_signal", not after_ngs.has("player_character_changed") and not after_ngs.has("modal_changed"), "after it only the reset wave of other systems: %s" % [after_ngs])
	var skin_args: Array = []
	for entry in w["log"]:
		if entry[0] == "player_character_changed":
			skin_args.append(entry[1][1] if (entry[1] as Array).size() > 1 else entry[1][0])
	t.check("new_game_skin_announced_final", skin_args == [&"fairy_meadow"] and seen.get("skin") == &"fairy_meadow", "player_character_changed %s" % [skin_args])
	t.check("new_game_state_reset_before_signal", seen.get("day") == 1 and seen.get("season") == &"foraar" and seen.get("year") == 1 and seen.get("hour") == 6
		and seen.get("flags") == {&"intro_pending": true, &"home_tier": 1, &"home_building": 0, &"home_upgrade_done": 0} and seen.get("zones") == [&"farm", &"city"] and seen.get("modals") == [] and seen.get("phase") == PH.PLAYING,
		"day/season/year/clock, flags %s, zones, modals gone, phase PLAYING" % [seen.get("flags")])
	t.check("new_game_intro_pending", gm.get_flag(gm.FLAG_INTRO_PENDING, false) == true and not gm.world_flags.has(&"dirty_flag"), "intro_pending=true, the dirty flag is gone")
	t.check("new_game_resets_own_state", gm.player_name == "Mia" and gm.farm_name == "Farmen" and gm.character_type == gm.CharacterType.FAIRY and gm.discovered_locations.is_empty()
		and gm.play_time_seconds == 0.0 and gm.minute == 0 and not gm.is_zone_unlocked(&"crystal_cave") and not t.tree.paused and gm.total_day() == 1, "")
	# TimeManager listens to new_game_started
	t.check("new_game_resets_time_manager", tm.weather == &"klart" and not tm.is_paused and tm.time_scale == 1.0 and _names(w["log"]).has("weather_changed"), "weather klart, clock running")
	_unwatch(w)
	# default skin per race and the explicit skin
	gm.start_new_game("A", gm.CharacterType.ANIMAL, "F")
	var animal_skin: StringName = gm.character_skin
	gm.start_new_game("B", gm.CharacterType.HOBBIT, "F")
	var hobbit_skin: StringName = gm.character_skin
	gm.start_new_game("G", gm.CharacterType.GHOST, "F")
	var ghost_skin: StringName = gm.character_skin
	gm.start_new_game("C", gm.CharacterType.FAIRY, "F", &"fairy_dusk")
	var explicit_skin: StringName = gm.character_skin
	t.check("new_game_default_and_explicit_skin", animal_skin == &"animal_fox" and hobbit_skin == &"hobbit_pip" and ghost_skin == &"ghost_bu" and explicit_skin == &"fairy_dusk", "animal %s hobbit %s ghost %s explicit %s" % [animal_skin, hobbit_skin, ghost_skin, explicit_skin])
	gm.start_new_game("", gm.CharacterType.ANIMAL, "")
	t.check("new_game_default_names", gm.player_name != "" and gm.farm_name != "", "empty names fall back to the translated defaults (%s / %s)" % [gm.player_name, gm.farm_name])
	# every system that has a reset() must be wired to the signal; the others land in waves 3-4 (P12 / P13 / P15 / P20)
	var wired := 0
	var pending: Array[String] = []
	var connected := {}
	for c in bus.new_game_started.get_connections():
		var owner_obj: Object = (c["callable"] as Callable).get_object()
		if owner_obj != null:
			connected[owner_obj] = true
	for autoload_name in ["EconomyManager", "QuestManager", "TimeManager", "ShopSystem", "AnimalHusbandry", "SaveManager"]:
		var node: Node = bus.get_node_or_null("/root/" + autoload_name)
		if node == null:
			pending.append(autoload_name + " (missing)")
		elif not node.has_method("reset"):
			pending.append(autoload_name)
		else:
			wired += 1
			t.check("new_game_wires_" + autoload_name, connected.has(node), "%s.reset() is connected to new_game_started" % autoload_name)
	if not pending.is_empty():
		t.skip("reset hooks still to come (wired by P12/P13/P15/P20): %s" % ", ".join(pending))
	# gold / inventory / quests: asserted functionally as soon as the owner's reset() exists
	var economy: Node = bus.get_node_or_null("/root/EconomyManager")
	if economy != null and economy.has_method("reset"):
		economy.gold = 4321
		gm.start_new_game("D", gm.CharacterType.ANIMAL, "F")
		t.check("new_game_resets_gold", economy.gold != 4321, "gold after a new game: %s" % economy.gold)
	t.check("new_game_resets_all", names.count("new_game_started") == 1 and wired >= 1, "one new_game_started per start_new_game; %d system(s) reset through it so far" % wired)


# ================================================================ GameManager: save dictionary

func _test_from_dict() -> void:
	gm.start_new_game("Mia", gm.CharacterType.FAIRY, "Farmen", &"fairy_stardust")
	gm.set_flag(&"friend_x", 2)
	gm.unlock_zone(&"dark_forest")
	gm.day = 16
	gm.season = &"sommer"
	gm.year = 2
	gm.hour = 14
	gm.minute = 5
	gm.play_time_seconds = 321.5
	var saved: Dictionary = gm.to_dict()
	var back: Dictionary = JSON.parse_string(JSON.stringify(saved))
	gm.start_new_game("Other", gm.CharacterType.ANIMAL, "X")
	gm.change_phase(PH.MENU)
	var w := _watch(["player_character_changed", "new_game_started", "day_started"])
	gm.from_dict(back)
	t.check("from_dict_restores_state", gm.player_name == "Mia" and gm.farm_name == "Farmen" and gm.character_type == gm.CharacterType.FAIRY and gm.character_skin == &"fairy_stardust"
		and gm.day == 16 and gm.season == &"sommer" and gm.year == 2 and gm.hour == 14 and gm.minute == 5 and gm.play_time_seconds == 321.5
		and gm.get_flag(&"friend_x") == 2 and gm.is_zone_unlocked(&"dark_forest"), "")
	t.check("from_dict_types_after_json", typeof(gm.day) == TYPE_INT and typeof(gm.hour) == TYPE_INT and typeof(gm.season) == TYPE_STRING_NAME and typeof(gm.year) == TYPE_INT
		and typeof(gm.character_skin) == TYPE_STRING_NAME and gm.unlocked_zones.get_typed_builtin() == TYPE_STRING_NAME, "ints and StringNames come back typed")
	t.check("from_dict_does_not_start_playing", gm.current_phase == PH.MENU and not t.tree.paused, "phase stays %d" % gm.current_phase)
	var skin_args: Array = []
	for entry in w["log"]:
		if entry[0] == "player_character_changed":
			skin_args.append(entry[1][1] if (entry[1] as Array).size() > 1 else entry[1][0])
	t.check("from_dict_emits_character_changed", skin_args == [&"fairy_stardust"] and not _names(w["log"]).has("new_game_started") and not _names(w["log"]).has("day_started"), "%s" % [skin_args])
	_unwatch(w)
	t.check("to_dict_total_day", int(saved["total_day"]) == gm.total_day_for(16, &"sommer", 2) and typeof(saved["season"]) == TYPE_STRING and typeof(saved["character_type"]) == TYPE_INT, "total_day %s in the dictionary for the title screen" % saved["total_day"])
	# a legacy / partial dictionary must not break
	gm.from_dict({})
	t.check("from_dict_empty_is_safe", gm.day == 1 and gm.hour == gm.day_start_hour() and gm.season == &"foraar" and gm.world_flags.is_empty(), "")
	# an unsafe flag in a save is dropped with a warning, the rest loads
	t.allow("and was dropped")
	t.info("expected engine warning below (declared with allow): from_dict drops an unsafe flag")
	gm.from_dict({"world_flags": {"ok": true, "bad": [1, 2], "n": 3}})
	t.expect_allowed("and was dropped", 1, "an unsafe flag in a save is reported")
	t.check("from_dict_drops_unsafe_flags", gm.get_flag(&"ok") == true and not gm.world_flags.has(&"bad") and gm.flag_int(&"n") == 3, "")
	gm.start_new_game("Tester", gm.CharacterType.ANIMAL, "Testgaarden")


# ================================================================ GameManager: zones

func _test_unlock_zone() -> void:
	gm.start_new_game("Tester", gm.CharacterType.ANIMAL, "Testgaarden")
	var w := _watch(["zone_unlocked", "zone_entered", "notification_posted"])
	gm.unlock_zone(&"crystal_cave")
	var unlocked := 0
	var entered := 0
	var toasts: Array = []
	for entry in w["log"]:
		match entry[0]:
			"zone_unlocked":
				unlocked += 1
				t.check("unlock_zone_payload", entry[1][0] == &"crystal_cave", "zone_unlocked(crystal_cave)")
			"zone_entered":
				entered += 1
			"notification_posted":
				toasts.append(entry[1])
	t.check("unlock_zone_signals", unlocked == 1 and entered == 0, "zone_unlocked x%d, zone_entered x%d" % [unlocked, entered])
	t.check("unlock_zone_toast", toasts.size() == 1 and toasts[0][2] == "zone" and str(toasts[0][0]) != "" and str(toasts[0][1]) != "", "one toast, icon zone: %s" % [toasts])
	t.check("unlock_toast_never_formats_a_raw_key", gm._format_one("NOTIF_ZONE_UNLOCKED_MSG", "x") == "NOTIF_ZONE_UNLOCKED_MSG" and gm._format_one("Open: %s", "x") == "Open: x",
		"an untranslated key (no placeholder) is returned as it is: no String formatting error")
	t.check("unlock_zone_state", gm.is_zone_unlocked(&"crystal_cave") and &"crystal_cave" in gm.unlocked_zones and not &"crystal_cave" in gm.discovered_locations, "unlocked, not discovered")
	w["log"].clear()
	gm.unlock_zone(&"crystal_cave")
	gm.unlock_zone(&"")
	t.check("unlock_zone_twice_is_silent", w["log"].is_empty(), "no second signal, no second toast")
	_unwatch(w)
	# entering a zone (WorldRoot2D's job) discovers it
	bus.zone_entered.emit(&"dark_forest")
	t.check("zone_entered_discovers", &"dark_forest" in gm.discovered_locations, "")


# ================================================================ GameManager: clock and calendar

func _test_clock() -> void:
	# (e) 25 hours from 06:00 land on 07:00 of the next day, in one pass
	var w := _watch(["day_ended", "day_started", "season_changed", "time_of_day_changed", "game_event"])
	_set_clock(1, &"foraar", 1, 6, 0)
	gm.advance_time(25 * 60)
	t.check("advance_time_25h", gm.day == 2 and gm.hour == 7 and gm.minute == 0 and gm.season == &"foraar",
		"06:00 + 25 h = day %d %02d:%02d" % [gm.day, gm.hour, gm.minute])
	t.check("advance_time_25h_signals", _names(w["log"]) == ["day_ended", "day_started", "game_event", "time_of_day_changed"] and w["log"][3][1] == [7, 0] and w["log"][0][1] == [1, &"foraar"] and w["log"][1][1] == [2, &"foraar"],
		"%s" % [_names(w["log"])])
	t.check("midnight_passed_event", w["log"][2][1] == [&"midnight_passed", {"day": 2, "season": "foraar"}], "game_event(midnight_passed) after day_started: %s" % [w["log"][2][1]])
	# exact multi-day skips
	w["log"].clear()
	_set_clock(1, &"foraar", 1, 6, 0)
	gm.advance_time(50 * 60)
	var fifty: bool = gm.day == 3 and gm.hour == 8 and _names(w["log"]).count("day_ended") == 2 and _names(w["log"]).count("day_started") == 2 and _names(w["log"]).count("time_of_day_changed") == 1 and _names(w["log"]).count("game_event") == 2
	_set_clock(1, &"foraar", 1, 6, 0)
	gm.advance_time(18 * 60)
	var exactly_midnight: bool = gm.day == 1 and gm.hour == 24 and gm.minute == 0      # 06:00 + 18 h is 00:00 of the SAME game day (raw hour 24)
	_set_clock(1, &"foraar", 1, 6, 0)
	gm.advance_time(20 * 60)
	var exactly_day_end: bool = gm.day == 2 and gm.hour == 2 and gm.minute == 0        # 06:00 + 20 h = 26:00: the day rolls, the clock restarts at 02:00
	_set_clock(1, &"foraar", 1, 23, 59)
	gm.advance_time(1)
	var one_minute: bool = gm.day == 1 and gm.hour == 24 and gm.minute == 0            # 23:59 + 1 min = 00:00 of the same day: no roll, no pass-out event
	_set_clock(1, &"foraar", 1, 25, 59)
	gm.advance_time(1)
	var one_minute_end: bool = gm.day == 2 and gm.hour == 2 and gm.minute == 0         # 01:59 (raw 25:59) + 1 min = the day end
	_set_clock(1, &"foraar", 1, 6, 0)
	var start_total: int = gm.total_day()
	gm.advance_time(29 * 24 * 60 + 90)
	var month_skip: bool = gm.total_day() == start_total + 29 and gm.hour == 7 and gm.minute == 30 and gm.season == &"sommer" and gm.day == 2
	t.check("advance_time_multiday", fifty and exactly_midnight and exactly_day_end and one_minute and one_minute_end and month_skip,
		"50 h -> day 3 08:00 %s; 18 h -> raw 24:00 of the same day %s; 20 h -> day 2 02:00 %s; 23:59 + 1 min -> raw 24:00 same day %s; 25:59 + 1 min -> day 2 02:00 %s; 29 days 90 min -> sommer day 2 07:30 %s" % [fifty, exactly_midnight, exactly_day_end, one_minute, one_minute_end, month_skip])
	# the clock hours handed to listeners are the raw game hours 2..25 (24 and 25 = 00:xx and 01:xx of the same day; never 26), minutes 0..59
	var hours_ok := true
	for entry in w["log"]:
		if entry[0] == "time_of_day_changed" and (int(entry[1][0]) < 2 or int(entry[1][0]) > 25 or int(entry[1][1]) < 0 or int(entry[1][1]) > 59):
			hours_ok = false
	w["log"].clear()
	_set_clock(1, &"foraar", 1, 23, 0)
	gm.advance_time(90)
	hours_ok = hours_ok and w["log"].size() == 1 and w["log"][0][0] == "time_of_day_changed" and w["log"][0][1] == [24, 30]
	t.check("time_of_day_changed_range", hours_ok, "raw hour 2..25 (a signal at 24:30 carries 24: the HUD shows 00:30), minute 0..59")
	# zero and negative skips
	w["log"].clear()
	_set_clock(1, &"foraar", 1, 10, 15)
	gm.advance_time(0)
	var zero_ok: bool = _names(w["log"]) == ["time_of_day_changed"] and gm.hour == 10 and gm.minute == 15
	w["log"].clear()
	gm.advance_time(-30)
	t.check("advance_time_zero_and_negative", zero_ok and w["log"].is_empty() and gm.hour == 10 and gm.minute == 15, "0 min emits the clock once, negative minutes are ignored")
	# season and year rollovers, in signal order
	w["log"].clear()
	_set_clock(28, &"foraar", 1, 23, 0)
	gm.advance_time(120)
	var still_28: bool = gm.day == 28 and gm.season == &"foraar" and gm.hour == 25 and w["log"].size() == 1      # 23:00 + 2 h = 01:00 of the SAME day 28: no season change yet
	w["log"].clear()
	_set_clock(28, &"foraar", 1, 25, 0)
	gm.advance_time(120)
	t.check("season_rollover", still_28 and gm.day == 1 and gm.season == &"sommer" and gm.year == 1 and gm.hour == 3 and _names(w["log"]) == ["day_ended", "season_changed", "day_started", "game_event", "time_of_day_changed"] and w["log"][1][1] == [&"sommer"],
		"day 28 foraar 23:00 + 2 h = still day 28 (01:00); 01:00 (raw 25:00) + 2 h = day 1 sommer 03:00: %s" % [_names(w["log"])])
	w["log"].clear()
	_set_clock(28, &"vinter", 1, 25, 0)
	gm.advance_time(120)
	t.check("year_rollover", gm.day == 1 and gm.season == &"foraar" and gm.year == 2 and w["log"][1][1] == [&"foraar"], "vinter 28 -> foraar day 1 of year 2")
	# end_day: day_ended then day_started, next morning 06:00
	w["log"].clear()
	_set_clock(5, &"sommer", 1, 21, 30)
	gm.end_day()
	t.check("end_day_signal_order", _names(w["log"]) == ["day_ended", "day_started", "time_of_day_changed"] and w["log"][0][1] == [5, &"sommer"] and w["log"][1][1] == [6, &"sommer"]
		and gm.day == 6 and gm.hour == 6 and gm.minute == 0, "%s (the bed emits no midnight_passed)" % [_names(w["log"])])
	# the audit's year-long loop
	_set_clock(1, &"foraar", 1, 6, 0)
	for i in 28 * 4 + 2:
		gm.end_day()
	t.check("end_day_full_year", gm.day == 3 and gm.season == &"foraar" and gm.year == 2 and gm.total_day() == 115, "114 end_day() calls: day %d %s year %d (total %d)" % [gm.day, gm.season, gm.year, gm.total_day()])
	_unwatch(w)


func _test_total_day() -> void:
	t.check("total_day_values", gm.total_day_for(1, &"foraar", 1) == 1 and gm.total_day_for(28, &"vinter", 1) == 112 and gm.total_day_for(1, &"foraar", 2) == 113
		and gm.total_day_for(16, &"sommer", 1) == 44, "Dag 1 .. Dag 112, year 2 starts at Dag 113")
	_set_clock(9, &"efteraar", 1, 6, 0)
	t.check("total_day_current", gm.total_day() == 2 * 28 + 9, "day 9 efteraar year 1 is Dag %d" % gm.total_day())


func _test_sleep_helper() -> void:
	var w := _watch(["day_ended", "day_started", "time_of_day_changed", "game_event"])
	# the bed in the evening
	_set_clock(4, &"foraar", 1, 21, 30)
	var days_passed: int = gm.sleep_until_morning()
	t.check("sleep_from_bed", days_passed == 1 and gm.day == 5 and gm.hour == 6 and gm.minute == 0 and _names(w["log"]) == ["day_ended", "day_started", "time_of_day_changed"], "21:30 -> next day 06:00")
	# pass-out: the natural 02:00 day roll already started the new day, sleeping must not skip another one
	w["log"].clear()
	_set_clock(4, &"foraar", 1, 25, 58)
	gm.advance_time(3)
	var rolled: bool = gm.day == 5 and gm.hour == 2 and gm.minute == 1 and _names(w["log"]).has("day_ended") and _names(w["log"]).count("game_event") == 1
	w["log"].clear()
	days_passed = gm.sleep_until_morning()
	t.check("sleep_after_passout_no_double_day", rolled and days_passed == 0 and gm.day == 5 and gm.hour == 6 and gm.minute == 0 and _names(w["log"]) == ["time_of_day_changed"],
		"after the 02:00 roll: wake at 06:00 of the same calendar day (day %d)" % gm.day)
	_unwatch(w)


# ================================================================ TimeManager: calendar names (injected Translation)

func _test_calendar_names() -> void:
	var injected := _inject_calendar_translations()
	TranslationServer.set_locale("da")
	_set_clock(16, &"foraar", 1, 6, 0)
	var da_text: String = tm.date_text(16, &"foraar")
	t.expect_eq(da_text, "Tirsdag 16. Blomstermåned", "date_text(16, foraar) in da")
	TranslationServer.set_locale("en")
	var en_text: String = tm.date_text(16, &"foraar")
	t.expect_eq(en_text, "Tuesday 16. Month of Blooms", "date_text(16, foraar) in en")
	TranslationServer.set_locale("da")
	var all_days := true
	for d in range(1, 29):
		all_days = all_days and tm.weekday_index(d) == (d - 1) % 7 and tm.weekday_name(d) == DA_WEEKDAYS[(d - 1) % 7]
	var months := true
	for s in ["foraar", "sommer", "efteraar", "vinter"]:
		months = months and tm.season_month_name(StringName(s)) == DA_MONTHS[s.to_upper()]
	var weather := true
	for id in ["klart", "regn", "taage", "sne", "torden"]:
		weather = weather and tm.weather_name(StringName(id)) == DA_WEATHER[id.to_upper()]
	TranslationServer.set_locale("en")
	var en_names: bool = tm.weekday_name(7) == "Sunday" and tm.season_month_name(&"vinter") == "Month of Frost" and tm.weather_name(&"klart") == "Sunny" and tm.weather_name(&"taage") == "Fog"
	TranslationServer.set_locale("da")
	var current: bool = tm.date_text() == "Tirsdag 16. Blomstermåned" and tm.weekday_name() == "Tirsdag" and tm.season_month_name() == "Blomstermåned"
	t.check("calendar_names", da_text == "Tirsdag 16. Blomstermåned" and en_text == "Tuesday 16. Month of Blooms" and all_days and months and weather and en_names and current,
		"date_text da/en, 28 weekdays %s, 4 months %s, 5 weather names %s, en names %s, defaults to today %s" % [all_days, months, weather, en_names, current])
	t.check("weekday_is_monday_on_day_one_of_every_season", tm.weekday_index(1) == 0 and tm.weekday_index(8) == 0 and tm.weekday_index(28) == 6 and tm.weekday_index(15) == 0, "Mandag = day 1 of every season")
	# time.first_weekday shifts the whole calendar (default 0 = Monday)
	gm.set_config_override("time.first_weekday", 2)
	var shifted: bool = tm.weekday_index(1) == 2 and tm.weekday_name(1) == "Onsdag" and tm.weekday_index(6) == 0 and tm.date_text(16, &"foraar") == "Torsdag 16. Blomstermåned"
	gm.set_config_override("time.first_weekday", -1)
	var wrapped: bool = tm.weekday_index(1) == 6
	gm.clear_config_overrides()
	t.check("first_weekday_config", shifted and wrapped and tm.weekday_index(1) == 0, "time.first_weekday=2: day 1 is Onsdag; the default is Mandag")
	for tr_obj in injected:
		TranslationServer.remove_translation(tr_obj)


func _inject_calendar_translations() -> Array:
	var made: Array = []
	for loc in ["da", "en"]:
		var tr_obj := Translation.new()
		tr_obj.locale = loc
		var days: Array[String] = DA_WEEKDAYS if loc == "da" else EN_WEEKDAYS
		var months: Dictionary = DA_MONTHS if loc == "da" else EN_MONTHS
		var weather: Dictionary = DA_WEATHER if loc == "da" else EN_WEATHER
		for i in 7:
			tr_obj.add_message("UI_WEEKDAY_%d" % (i + 1), days[i])
		for key in months:
			tr_obj.add_message("UI_MONTH_" + key, months[key])
		for key in weather:
			tr_obj.add_message("UI_WEATHER_" + key, weather[key])
		TranslationServer.add_translation(tr_obj)
		made.append(tr_obj)
	return made


# ================================================================ TimeManager: weather

func _test_weather() -> void:
	gm.start_new_game("Tester", gm.CharacterType.ANIMAL, "Testgaarden")
	_set_clock(1, &"foraar", 1, 6, 0)
	# set_weather announces, validates, and is_raining follows only regn
	var w := _watch(["weather_changed"])
	tm.set_weather(&"regn")
	var rain: bool = tm.weather == &"regn" and tm.is_raining() and w["log"].size() == 1 and w["log"][0][1] == [&"regn"]
	tm.set_weather(&"torden")
	var thunder_is_not_rain: bool = not tm.is_raining()
	t.allow("unknown weather id")
	t.info("expected engine error below (declared with allow): set_weather with an unknown id")
	tm.set_weather(&"hagl")
	t.expect_allowed("unknown weather id", 1, "an unknown weather id is refused")
	t.check("weather_set_and_announced", rain and thunder_is_not_rain and tm.weather == &"torden" and w["log"].size() == 2, "weather_changed(regn), is_raining only for regn, unknown id refused")
	_unwatch(w)
	# the roll honours the configured chances; snow only in vinter
	gm.set_config_override("time.weather_chances.foraar", {"regn": 0.25, "taage": 0.15})
	_set_clock(1, &"foraar", 1, 6, 0)
	tm.roll_weather(0.0)
	var r0: StringName = tm.weather
	tm.roll_weather(0.30)
	var r1: StringName = tm.weather
	tm.roll_weather(0.90)
	var r2: StringName = tm.weather
	t.check("weather_roll_uses_config_chances", r0 == &"regn" and r1 == &"taage" and r2 == &"klart", "roll 0.0 -> %s, 0.30 -> %s, 0.90 -> %s" % [r0, r1, r2])
	gm.set_config_override("time.weather_chances.foraar", {"sne": 1.0})
	tm.roll_weather(0.5)
	var no_spring_snow: bool = tm.weather == &"klart"
	gm.set_config_override("time.weather_chances.vinter", {"sne": 0.5})
	_set_clock(1, &"vinter", 1, 6, 0)
	tm.roll_weather(0.2)
	t.check("weather_snow_only_in_vinter", no_spring_snow and tm.weather == &"sne", "snow chance outside vinter is ignored")
	# weights (not probabilities): normalised, klart may be listed explicitly, the buckets run regn..torden then klart
	gm.set_config_override("time.weather_chances.sommer", {"klart": 6, "regn": 3, "torden": 1})
	_set_clock(1, &"sommer", 1, 6, 0)
	var normalised: Dictionary = tm.weather_chances()
	tm.roll_weather(0.10)
	var w_a: StringName = tm.weather
	tm.roll_weather(0.35)
	var w_b: StringName = tm.weather
	tm.roll_weather(0.50)
	var w_c: StringName = tm.weather
	t.check("weather_weights_are_normalised", is_equal_approx(float(normalised.get(&"klart", 0.0)), 0.6) and is_equal_approx(float(normalised.get(&"regn", 0.0)), 0.3)
		and is_equal_approx(float(normalised.get(&"torden", 0.0)), 0.1) and w_a == &"regn" and w_b == &"torden" and w_c == &"klart",
		"klart 6 / regn 3 / torden 1 -> %s; rolls 0.10 %s, 0.35 %s, 0.50 %s" % [normalised, w_a, w_b, w_c])
	gm.clear_config_overrides()
	# the real table of game_balance.lua: every season sums to 1, only known ids, snow only in vinter
	var table_ok := true
	var table_note := ""
	for season_id in [&"foraar", &"sommer", &"efteraar", &"vinter"]:
		var chances: Dictionary = tm.weather_chances(season_id)
		var sum := 0.0
		for id in chances:
			sum += float(chances[id])
			table_ok = table_ok and id in tm.WEATHER_IDS
		table_ok = table_ok and is_equal_approx(sum, 1.0) and chances.has(&"klart") and (season_id == &"vinter" or not chances.has(&"sne"))
		table_note += "%s %s; " % [season_id, chances.keys()]
	t.check("weather_table_is_valid", table_ok, table_note)
	# the night hours come from time.night_start_hour / time.night_end_hour
	_set_clock(1, &"foraar", 1, 18, 0)
	var day_at_18: bool = not tm.is_night()
	gm.set_config_override("time.night_start_hour", 18)
	var night_at_18: bool = tm.is_night()
	gm.clear_config_overrides()
	_set_clock(1, &"foraar", 1, 4, 0)
	t.check("is_night_from_config", day_at_18 and night_at_18 and tm.is_night(), "20:00-05:00 by default, configurable")
	# the default table still only produces known ids over many rolls, and every season can be sunny
	var seen_ids := {}
	for season_id in [&"foraar", &"sommer", &"efteraar", &"vinter"]:
		_set_clock(1, season_id, 1, 6, 0)
		for i in 200:
			tm.roll_weather()
			seen_ids[tm.weather] = true
			if season_id != &"vinter" and tm.weather == &"sne":
				seen_ids["SNOW_OUTSIDE_VINTER"] = true
	var known := true
	for id in seen_ids.keys():
		known = known and (id in tm.WEATHER_IDS or id == "SNOW_OUTSIDE_VINTER")
	t.check("weather_default_rolls_are_valid", known and not seen_ids.has("SNOW_OUTSIDE_VINTER") and seen_ids.has(&"klart"), "ids seen: %s" % [seen_ids.keys()])
	# once per day, BEFORE the other day_started listeners
	_set_clock(1, &"foraar", 1, 6, 0)
	tm.weather_rolls = 0
	tm.roll_weather_for_day()   # the day this clock starts on: may or may not be rolled yet, then it is
	var base_rolls: int = tm.weather_rolls
	var observed := {"rolls": -1}
	var listener := func(_d, _s) -> void: observed["rolls"] = tm.weather_rolls
	bus.day_started.connect(listener)
	gm.end_day()
	bus.day_started.disconnect(listener)
	t.check("weather_rolled_before_day_started", observed["rolls"] == base_rolls + 1 and tm.weather_rolls == base_rolls + 1, "a day_started listener already saw the roll (%s), total %d" % [observed["rolls"], tm.weather_rolls])
	bus.day_started.emit(gm.day, gm.season)
	t.check("weather_rolled_once_per_day", tm.weather_rolls == base_rolls + 1, "a stray day_started of the same day does not roll again")
	# the guarantee does not depend on connection order: with TimeManager's own day_started handler taken away,
	# GameManager still rolls first (a listener connected BEFORE TimeManager would otherwise see yesterday's weather)
	var own_handler := Callable(tm, "_on_day_started")
	var was_connected: bool = bus.day_started.is_connected(own_handler)
	if was_connected:
		bus.day_started.disconnect(own_handler)
	var seen_alone := {"rolls": -1}
	var alone := func(_d, _s) -> void: seen_alone["rolls"] = tm.weather_rolls
	bus.day_started.connect(alone)
	var before_alone: int = tm.weather_rolls
	gm.end_day()
	bus.day_started.disconnect(alone)
	if was_connected:
		bus.day_started.connect(own_handler)
	t.check("weather_rolled_by_game_manager_before_listeners", was_connected and seen_alone["rolls"] == before_alone + 1,
		"without TimeManager's own handler a listener still saw the new roll (%s, was %d)" % [seen_alone["rolls"], before_alone])
	base_rolls = tm.weather_rolls
	gm.advance_time(25 * 60)
	var after_25h: int = tm.weather_rolls
	gm.advance_time(50 * 60)
	t.check("weather_one_roll_per_crossed_midnight", after_25h == base_rolls + 1 and tm.weather_rolls == after_25h + 2, "25 h = 1 roll, 50 h = 2 rolls")
	# reset (new game) and save round trip
	tm.set_weather(&"regn")
	tm.pause_time()
	tm.reset()
	t.check("time_manager_reset", tm.weather == &"klart" and not tm.is_paused and tm.time_scale == 1.0 and tm.weather_rolls == 0, "")
	tm.set_weather(&"taage")
	var saved: Dictionary = tm.to_dict()
	var back: Dictionary = JSON.parse_string(JSON.stringify(saved))
	tm.set_weather(&"klart")
	var w2 := _watch(["weather_changed"])
	tm.from_dict(back)
	t.check("time_manager_save_roundtrip", tm.weather == &"taage" and w2["log"].size() == 1 and int(back["weather_day"]) == gm.total_day(), "weather and the day it belongs to survive JSON")
	_unwatch(w2)
	tm.from_dict({"weather": "bogus"})
	t.check("time_manager_from_dict_bad_weather", tm.weather == &"klart", "unknown saved weather falls back to klart")


# ================================================================ TimeManager: ticking and pausing

func _test_time_ticking() -> void:
	gm.start_new_game("Tester", gm.CharacterType.ANIMAL, "Testgaarden")
	gm.set_config_override("time.minutes_per_real_second", 2.0)
	_set_clock(1, &"foraar", 1, 6, 0)
	tm.reset()
	tm.tick(0.5)
	var one_minute: bool = gm.hour == 6 and gm.minute == 1
	tm.tick(0.25)
	var held_back: bool = gm.minute == 1
	tm.tick(0.25)
	t.check("time_tick_rate", one_minute and held_back and gm.minute == 2, "2 game minutes per real second: 1 s = 06:02 (%02d:%02d)" % [gm.hour, gm.minute])
	tm.pause_time()
	tm.pause_time()
	tm.tick(10.0)
	var frozen: bool = gm.minute == 2
	tm.resume_time()
	tm.tick(0.5)
	t.check("pause_time_is_idempotent", frozen and not tm.is_paused and gm.minute == 3, "pause twice, resume once: the clock runs again")
	tm.resume_time()
	t.check("resume_time_is_idempotent", not tm.is_paused, "")
	gm.push_modal(&"inventory")
	tm.tick(10.0)
	var modal_frozen: bool = gm.minute == 3
	gm.pop_modal(&"inventory")
	gm.push_modal(&"dialogue", false)
	tm.tick(10.0)
	var cutscene_frozen: bool = gm.minute == 3
	gm.pop_modal(&"dialogue")
	gm.change_phase(PH.MENU)
	tm.tick(10.0)
	var menu_frozen: bool = gm.minute == 3
	gm.change_phase(PH.PLAYING)
	t.check("clock_stops_in_modals_and_menus", modal_frozen and cutscene_frozen and menu_frozen, "paused modal %s, dialogue %s, menu %s" % [modal_frozen, cutscene_frozen, menu_frozen])
	tm.set_time_scale(2.0)
	tm.tick(0.5)
	t.check("time_scale", gm.minute == 5, "time scale 2: +2 minutes for 0.5 s (%02d:%02d)" % [gm.hour, gm.minute])
	tm.set_time_scale(1.0)
	# ticking across midnight does NOT end the day (it runs to 02:00); ticking across 02:00 keeps the calendar exact
	_set_clock(1, &"foraar", 1, 23, 59)
	tm.tick(0.5)
	var past_midnight: bool = gm.day == 1 and gm.hour == 24 and gm.minute == 0
	_set_clock(1, &"foraar", 1, 25, 59)
	tm.tick(0.5)
	t.check("tick_crosses_midnight", past_midnight and gm.day == 2 and gm.hour == 2 and gm.minute == 0, "23:59 + 1 tick = day 1 raw 24:00 (00:00 of the same day); 01:59 + 1 tick = day 2 02:00")
	var fraction_ok := true
	_set_clock(1, &"foraar", 1, 12, 0)
	fraction_ok = is_equal_approx(tm.get_day_fraction(), 0.5)
	t.check("day_fraction", fraction_ok and tm.is_night() == false, "noon is half of the day")
	gm.clear_config_overrides()


# ================================================================ no mouse capture in the autoloads

func _test_no_mouse_capture() -> void:
	var offenders: Array[String] = []
	var checked := 0
	for prop in ProjectSettings.get_property_list():
		var prop_name := str(prop["name"])
		if not prop_name.begins_with("autoload/"):
			continue
		var path := str(ProjectSettings.get_setting(prop_name)).trim_prefix("*")
		if not path.ends_with(".gd"):
			continue
		checked += 1
		if _blank_strings_and_comments(FileAccess.get_file_as_string(path)).contains("mouse_mode"):
			offenders.append(path)
	t.check("no_mouse_capture", offenders.is_empty() and checked >= 11,
		"%d autoload scripts scanned, none touches Input.mouse_mode %s (the cursor itself is menus.cursor_always_visible, P16)" % [checked, offenders])


# ================================================================ helpers

func _set_clock(p_day: int, p_season: StringName, p_year: int, p_hour: int, p_minute: int) -> void:
	gm.day = p_day
	gm.season = p_season
	gm.year = p_year
	gm.hour = p_hour
	gm.minute = p_minute


func _arity_of(signal_name: String) -> int:
	for info in bus.get_signal_list():
		if info["name"] == signal_name:
			return (info["args"] as Array).size()
	return 0


## Connects a recorder to the named EventBus signals. box["log"] holds [signal name, [arguments]] in emission order.
func _watch(signal_names: Array) -> Dictionary:
	var box := {"log": [], "cbs": {}}
	for n in signal_names:
		var sig_name := str(n)
		var arity := _arity_of(sig_name)
		var cb := func(a1 = null, a2 = null, a3 = null, a4 = null, a5 = null) -> void:
			(box["log"] as Array).append([sig_name, [a1, a2, a3, a4, a5].slice(0, arity)])
		Signal(bus, sig_name).connect(cb)
		box["cbs"][sig_name] = cb
	return box


func _unwatch(box: Dictionary) -> void:
	for sig_name in box["cbs"]:
		var s := Signal(bus, str(sig_name))
		if s.is_connected(box["cbs"][sig_name]):
			s.disconnect(box["cbs"][sig_name])
	# each recorder lambda captured `box`, and `box` holds the lambdas: break the reference cycle or the script leaks
	(box["cbs"] as Dictionary).clear()


func _names(log: Array) -> Array:
	var out: Array = []
	for entry in log:
		out.append(entry[0])
	return out
