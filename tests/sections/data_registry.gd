extends RefCounted
## Section data_registry (package P10, fix round RT4 of the towns / social addendum): the generic Lua kind `registry` and the
## four social api functions of LuaRuntime.
##
## Named checks: data_registry.registry_kind_loads_lints_and_claims, data_registry.lint_kinds_include_registry,
## data_registry.api_functions_nil_without_manager, plus data_registry.registry_header_findings, data_registry.registry_reload_clears,
## data_registry.until_key_is_flagged, data_registry.api_functions_late_bound, data_registry.api_unknown_names_log_once.
##
## What the kind is (addendum 4.8 / 8.6): `kind = "registry"` + `registry = "<name>"` + a top-level table of that name =
## { <id> = {...} } (routines, buildings, events, festivals). LuaRuntime.get_registry(name) -> Dictionary and
## get_registry_entry(name, id) -> Dictionary ({} when unknown); each id is claimed once across files (a second claim lands in
## LuaRuntime.data_report, the later file wins); a file without a usable header is the finding `registry_header`.
##
## The four api functions answer through the SocialManager autoload of S-core, late-bound. S-core does not exist in this tree
## yet, so the section proves the contract in both directions WITHOUT it: no manager -> nil, no effect, no engine message; a
## fake manager (a node named SocialManager with the same methods) -> the calls are forwarded with the documented arguments
## and the answers arrive typed. When the real autoload exists the section detaches it for the duration of its legs and puts it
## back (same place, same order); the late-bound path with the REAL manager is proven by S-core's own section.
##
## Fixtures: tests/fixtures/lua/registry_*.lua and social_api.lua.
const SECTION := "data_registry"
const TIMEOUT_S := 60.0
const FIX := "res://tests/fixtures/lua/"
const SOCIAL := "SocialManager"
const NEW_API := ["get_hearts", "add_hearts", "is_birthday", "festival"]


## A stand-in for S-core's SocialManager: the four methods LuaRuntime calls, recording what it was asked.
class FakeSocial extends Node:
	var hearts_by_npc: Dictionary = {"fixture_npc": 3}
	var birthdays: Array = ["fixture_npc"]
	var festival: StringName = &"fixture_fest"
	var calls: Array = []

	func hearts(npc: Variant) -> int:
		calls.append(["hearts", npc])
		return int(hearts_by_npc.get(str(npc), 0))

	func add_hearts(npc: Variant, n: int, source: StringName = &"quest") -> Dictionary:
		calls.append(["add_hearts", npc, n, source])
		hearts_by_npc[str(npc)] = int(hearts_by_npc.get(str(npc), 0)) + n
		return {"ok": true}

	func is_birthday(npc: Variant) -> bool:
		calls.append(["is_birthday", npc])
		return str(npc) in birthdays

	func festival_active() -> StringName:
		calls.append(["festival_active"])
		return festival


## A manager that only has some of the methods (an unfinished S-core): the missing ones must read as "no manager".
class HalfSocial extends Node:
	func hearts(_npc: Variant) -> int:
		return 7


var _t
var _lr: Node
var _gm: Node
var _saved_flags: Dictionary = {}
var _detached: Node = null
var _detached_index: int = -1


func run(t) -> void:
	_t = t
	_lr = t.autoload("LuaRuntime")
	_gm = t.autoload("GameManager")
	if _lr == null or _gm == null:
		t.fail("LuaRuntime / GameManager autoloads are missing")
		return
	_saved_flags = (_gm.world_flags as Dictionary).duplicate(true)
	_lint_kinds()
	_until_key()
	if _registry_kind():
		_registry_headers()
		_registry_reload()
	_api_without_manager()
	_api_with_manager()
	_api_unknown_names()
	# leave the runtime and the game state as found (the fixtures were loaded through load_file)
	_attach_real_social()
	_lr.reload_scripts()
	var flags: Dictionary = _gm.world_flags
	flags.clear()
	for k in _saved_flags:
		flags[k] = _saved_flags[k]


# ------------------------------------------------------------------------------------------------ lint kinds

func _lint_kinds() -> void:
	var t = _t
	var kinds: Array = LuaLint.KINDS
	var all_there := true
	for k in ["config", "items", "quest", "quests", "dialogue", "recipes", "shops", "registry"]:
		all_there = all_there and (k in kinds)
	var clean: Array = _lr.lint_source("kind = \"registry\"\nregistry = \"r\"\nr = { a = { x = 1 } }\n", "inline_registry.lua")
	var bogus: Array = _lr.lint_source("kind = \"bogus\"\nr = { a = { x = 1 } }\n", "inline_bogus.lua")
	var missing: Array = _lr.lint_source("r = { a = { x = 1 } }\n", "inline_missing.lua")
	var bogus_text := str(bogus[0]["message"]) if not bogus.is_empty() else ""
	var missing_text := str(missing[0]["message"]) if not missing.is_empty() else ""
	var ok: bool = all_there and clean.is_empty() \
		and bogus.size() == 1 and bogus[0]["rule"] == "kind_unknown" and bogus_text.contains("registry") \
		and missing.size() == 1 and missing[0]["rule"] == "kind_missing" and missing_text.contains("registry")
	t.check("lint_kinds_include_registry", ok, "LuaLint.KINDS has all of config items quest(s) dialogue recipes shops registry; a registry file lints clean; kind_unknown / kind_missing name `registry`: %s | %s" % [bogus_text, missing_text])
	# the repo's own files still lint clean with the wider kind list (nothing else changed)
	_lr.reload_scripts()
	t.expect(_lr.lint_report.is_empty(), "every Lua file under res://lua still lints clean (%d findings)" % _lr.lint_report.size())


## `until` is a Lua reserved word: real Lua rejects it as a table key, so the lint says so (routines use leave / stay / from).
func _until_key() -> void:
	var t = _t
	var bad: Array = _lr.lint_source("kind = \"registry\"\nregistry = \"r\"\nr = { a = { blocks = { { at = \"x\", until = 18 }, { at = \"y\", stay = 2 } } } }\n", "inline_until.lua")
	var bracket: Array = _lr.lint_source("kind = \"registry\"\nregistry = \"r\"\nr = { a = { [\"until\"] = 18, leave = 18, from = 6 } }\n", "inline_bracket.lua")
	var other: Array = _lr.lint_source("kind = \"config\"\nconfig = { x = { then = 1, ok = 2 } }\n", "inline_then.lua")
	var finding: Dictionary = bad[0] if not bad.is_empty() else {}
	t.check("until_key_is_flagged", bad.size() == 1 and finding["rule"] == "reserved_key" and finding["token"] == "until" and finding["line"] == 3 and str(finding["message"]).contains("leave / stay / from") \
		and bracket.is_empty() and other.size() == 1 and other[0]["rule"] == "reserved_key" and other[0]["token"] == "then",
		"`{ until = 18 }` is the finding reserved_key on its line with the routine hint, `[\"until\"] = 18`, leave, stay and from are clean, any other reserved word as a key is flagged too: %s" % str(bad))


# ------------------------------------------------------------------------------------------------ registry kind

## false when LuaRuntime has no registry API at all (the later legs would only be script errors).
func _registry_kind() -> bool:
	var t = _t
	if not (_lr.has_method("get_registry") and _lr.has_method("get_registry_entry")):
		t.check("registry_kind_loads_lints_and_claims", false, "LuaRuntime has no get_registry / get_registry_entry")
		return false
	_lr.reload_scripts()
	var data_before: int = _lr.data_report.size()
	var mark: int = t.log_mark()
	var sids: Array[String] = []
	for f in ["registry_routines_a.lua", "registry_routines_b.lua", "registry_buildings.lua"]:
		var sid: String = _lr.load_file(FIX + f)
		sids.append(sid)
		t.expect(sid == "tests/fixtures/lua/" + f.trim_suffix(".lua") and _lr.has_script(sid) and (_lr._scripts[sid] as Dictionary)["kind"] == "registry", "load_file(%s) registers the file as kind registry (script id %s)" % [f, sid])
	t.expect_clean_since(mark, "loading registry files logs no engine error or warning")
	# loads: one registry fed by two files, ids in load order, a second registry next to it
	var routines: Dictionary = _lr.get_registry("fixture_routines")
	var buildings: Dictionary = _lr.get_registry("fixture_buildings")
	t.expect(routines.keys() == ["fixture_gardener", "fixture_baker", "fixture_mayor"], "get_registry(\"fixture_routines\") holds the ids of both files in load order: %s" % str(routines.keys()))
	t.expect(buildings.keys() == ["fixture_bakery", "fixture_night_inn"] and not buildings.has("fixture_gardener") and not routines.has("fixture_bakery"), "a second registry does not leak into the first: %s" % str(buildings.keys()))
	var gardener: Dictionary = _lr.get_registry_entry("fixture_routines", "fixture_gardener")
	var blocks: Array = (gardener.get("plans", {}).get("work", {}) as Dictionary).get("blocks", [])
	var select: Array = gardener.get("select", [])
	var shape_ok: bool = gardener.get("home") == "hoppe_hut" and gardener.get("priority") == 4 and typeof(gardener.get("priority")) == TYPE_INT \
		and blocks.size() == 4 and blocks[0]["from"] == 6.5 and typeof(blocks[0]["from"]) == TYPE_FLOAT and blocks[3]["from"] == 22 and typeof(blocks[3]["from"]) == TYPE_INT \
		and blocks[2]["leave"] == 16.5 and gardener["plans"]["rest"]["blocks"][0]["stay"] == 2 \
		and select.size() == 2 and select[0]["plan"] == "rest" and select[0]["when"]["weekday"] == [6] and typeof(select[0]["when"]["weekday"][0]) == TYPE_INT and select[1] == {"plan": "work"}
	t.expect(shape_ok, "an entry arrives with its nested tables intact (floats stay floats, integers integers, arrays of tables arrays, {} Dictionary): %s" % str(gardener).left(160))
	var bakery: Dictionary = _lr.get_registry_entry("fixture_buildings", "fixture_bakery")
	t.expect(bakery.get("kind") == "shop" and bakery.get("hours") == [6, 18] and (_lr._scripts[sids[2]] as Dictionary)["kind"] == "registry", "a field named `kind` inside an entry does not disturb the file's own `kind` header: %s" % str(bakery))
	t.expect(_lr.get_registry_entry("fixture_routines", "nobody").is_empty() and _lr.get_registry_entry("fixture_nothing", "fixture_gardener").is_empty() and _lr.get_registry("fixture_nothing").is_empty() and typeof(_lr.get_registry("fixture_nothing")) == TYPE_DICTIONARY and typeof(_lr.get_registry_entry("fixture_nothing", "x")) == TYPE_DICTIONARY, "unknown registry or id: {} (a Dictionary, never null)")
	var scratch: Dictionary = _lr.get_registry("fixture_nothing")
	scratch["leak"] = true
	t.expect(_lr.get_registry("fixture_nothing").is_empty() and not _lr._registries.has("fixture_nothing"), "writing into the answer for an unknown registry creates nothing in the runtime")
	# lints: the good files lint clean, nothing was added to lint_report by loading them
	var lint_clean := true
	for f in ["registry_routines_a.lua", "registry_routines_b.lua", "registry_buildings.lua"]:
		var findings: Array = _lr.lint_source(FileAccess.get_file_as_string(FIX + f), FIX + f)
		lint_clean = lint_clean and findings.is_empty()
		t.expect(findings.is_empty(), "fixture %s is inside the subset and lints clean %s" % [f, str(findings)])
	# claims: fixture_baker is in both routine files: reported once, the later file wins, never a lint finding
	var dups: Array = []
	for n in _lr.data_report:
		if str(n["rule"]) == "duplicate_id" and str(n["token"]) == "fixture_baker":
			dups.append(n)
	var winner: Dictionary = _lr.get_registry_entry("fixture_routines", "fixture_baker")
	var claims_ok: bool = dups.size() == 1 and str(dups[0]["message"]).contains("registry:fixture_routines") and str(dups[0]["path"]).ends_with("registry_routines_b.lua") \
		and str(dups[0]["message"]).contains("tests/fixtures/lua/registry_routines_a") and winner.get("source") == "b" and _lr.data_report.size() == data_before + 1
	t.check("registry_kind_loads_lints_and_claims", routines.size() == 3 and buildings.size() == 2 and lint_clean and _lr.lint_report.is_empty() and claims_ok,
		"3 routine ids from 2 files + 2 building ids load; the fixtures lint clean (lint_report %d findings); fixture_baker claimed twice = one duplicate_id note (%d), later file wins (source %s): %s" % [_lr.lint_report.size(), dups.size(), str(winner.get("source")), str(dups)])
	# the claim is per registry and per id: the same id in ANOTHER registry is not a duplicate, and loading a file again is idempotent
	var notes_before: int = _lr.data_report.size()
	_lr.load_file(FIX + "registry_stalls.lua")
	_lr.load_file(FIX + "registry_buildings.lua")
	t.expect(_lr.data_report.size() == notes_before and _lr.get_registry_entry("fixture_stalls", "fixture_baker").get("stall") == "bread" and _lr.get_registry_entry("fixture_routines", "fixture_baker").get("source") == "b" and _lr.get_registry("fixture_buildings").size() == 2,
		"the same id in another registry (fixture_stalls.fixture_baker) and a file loaded twice add no duplicate note: %d new" % (_lr.data_report.size() - notes_before))
	return true


func _registry_headers() -> void:
	var t = _t
	_lr.reload_scripts()
	var mark: int = t.log_mark()
	var expected := {"registry_bad_noheader.lua": "", "registry_bad_notable.lua": "fixture_ghosts", "registry_bad_reserved.lua": "functions"}
	var problems: Array[String] = []
	for f in expected:
		var before: int = _lr.lint_report.size()
		var sid: String = _lr.load_file(FIX + f)
		var added: Array = _lr.lint_report.slice(before)
		var hit: Array = added.filter(func(x: Dictionary) -> bool: return str(x["rule"]) == "registry_header")
		if sid == "" or hit.size() != 1 or str(hit[0]["token"]) != str(expected[f]) or not str(hit[0]["path"]).ends_with(f) or not str(hit[0]["message"]).contains("registry"):
			problems.append("%s -> %s" % [f, str(added)])
	t.expect_clean_since(mark, "loading files with a bad registry header logs no engine error or warning")
	t.check("registry_header_findings", problems.is_empty() and _lr.lint_report.size() == 3, "a registry file without `registry = \"<name>\"`, without its table, or named like a parser result key (functions) is exactly one registry_header finding each; %s" % str(problems))
	var leaked := false
	for name in ["", "fixture_ghosts", "functions", "fixture_orphans", "fixture_ghost"]:
		leaked = leaked or (_lr._registries.has(name) and not (_lr._registries[name] as Dictionary).is_empty())
	# Real registry files (lua/buildings/*.lua) load through reload_scripts(); the bad fixtures must add nothing on top of them.
	var only_real := true
	for name in _lr._registries:
		only_real = only_real and str(name) != "" and not str(name).begins_with("fixture_") and str(name) != "functions" and str(name) != "fixture_orphans"
	t.expect(not leaked and only_real and _lr.get_registry("functions").is_empty() and _lr.get_registry_entry("fixture_orphans", "fixture_nobody").is_empty(), "a file with a bad header registers nothing (no registry named \"\", fixture_ghosts, functions or fixture_orphans)")
	# the lint TOOL reports it too (default root = res://lua: add a bad file there is not allowed, so assert the rule is on the list)
	var rules: Dictionary = _t.run_godot_script("res://tools/lua/lint.gd", PackedStringArray(["--list-rules"]))
	t.expect(str(rules["output"]).contains("registry_header") and str(rules["output"]).contains("reserved_key"), "tools/lua/lint.gd --list-rules names registry_header and reserved_key")


func _registry_reload() -> void:
	var t = _t
	for f in ["registry_routines_a.lua", "registry_buildings.lua", "registry_bad_notable.lua"]:
		_lr.load_file(FIX + f)
	t.expect(not _lr.get_registry("fixture_routines").is_empty() and not _lr.lint_report.is_empty(), "precondition: registries and a finding are loaded")
	_lr.reload_scripts()
	# Real registry files (lua/buildings/*.lua) are reloaded by reload_scripts(); the FIXTURE registries and findings must be gone.
	var fixtures_gone := true
	for name in ["fixture_routines", "fixture_buildings", "fixture_stalls", "fixture_ghosts", ""]:
		fixtures_gone = fixtures_gone and _lr.get_registry(name).is_empty()
	t.check("registry_reload_clears", fixtures_gone and _lr.lint_report.is_empty() and not _lr.has_script("tests/fixtures/lua/registry_routines_a"),
		"reload_scripts() forgets every fixture registry, finding and fixture script (F9 hot reload leaves no stale ids)")


# ------------------------------------------------------------------------------------------------ the four api functions

func _api_without_manager() -> void:
	var t = _t
	_detach_real_social()
	t.expect(_t.tree.root.get_node_or_null(SOCIAL) == null, "precondition: no SocialManager autoload in the tree for this leg")
	_lr.reload_scripts()
	var sid: String = _lr.load_file(FIX + "social_api.lua")
	t.expect(sid == "tests/fixtures/lua/social_api" and _lr._dialogue_modules.has("fixture_social_api") and _lr.lint_report.is_empty(), "the social api fixture registers and lints clean: %s" % str(_lr.lint_report))
	var flags_before: Dictionary = (_gm.world_flags as Dictionary).duplicate(true)
	var mark: int = t.log_mark()
	var results := {}
	results["direct"] = [_lr._call_api("get_hearts", ["fixture_npc"]), _lr._call_api("add_hearts", ["fixture_npc", 2]), _lr._call_api("is_birthday", ["fixture_npc"]), _lr._call_api("festival", [])]
	results["lua"] = [_lr._invoke_function(sid, "hearts_of", ["fixture_npc"]), _lr._invoke_function(sid, "bump", ["fixture_npc", 2]), _lr._invoke_function(sid, "is_bday", ["fixture_npc"]), _lr._invoke_function(sid, "festival_now", [])]
	var all_nil := true
	for k in results:
		for v in results[k]:
			all_nil = all_nil and v == null
	t.expect_clean_since(mark, "calling the social functions without a manager logs no engine error or warning")
	var unknown_logged := false
	for name in NEW_API:
		unknown_logged = unknown_logged or _lr._logged_once.keys().any(func(m: String) -> bool: return m.begins_with("unknown Lua function `%s`" % name))
	var no_effect: bool = (_gm.world_flags as Dictionary) == flags_before and not (_gm.world_flags as Dictionary).has("friend_fixture_npc")
	# the documented patterns around the nil answers: `or 0`, and a comparison that is simply false
	var stage: Variant = _lr._invoke_function(sid, "stage_of", ["fixture_npc"])
	var context_hearts: Variant = _lr._invoke_function(sid, "hearts_of_context", [{"hearts": 6}])
	var fallback_hearts: Variant = _lr._invoke_function(sid, "hearts_of_context", [{}])
	_gm.set_flag(&"friend_fixture_npc", 5)
	var flag_hearts: Variant = _lr._invoke_function(sid, "hearts_of_context", [{}])
	var festival_on: Variant = _lr._invoke_function(sid, "festival_is_on", [])
	t.check("api_functions_nil_without_manager", all_nil and not unknown_logged and no_effect and stage == "stranger" and context_hearts == 6 and fallback_hearts == 0 and flag_hearts == 5 and festival_on == true,
		"without SocialManager api.get_hearts / add_hearts / is_birthday / festival answer nil (direct and from Lua), are NOT the unknown-function path, change no flag (friend_fixture_npc unset); `api.get_hearts(npc) or 0` reads 0 (stage %s), `context.hearts or friend_x or 0` reads %s / %s / %s; results %s" % [str(stage), str(context_hearts), str(fallback_hearts), str(flag_hearts), str(results)])


func _api_with_manager() -> void:
	var t = _t
	_detach_real_social()
	var fake := FakeSocial.new()
	fake.name = SOCIAL
	_t.tree.root.add_child(fake)
	_lr.reload_scripts()
	var sid: String = _lr.load_file(FIX + "social_api.lua")
	var mark: int = t.log_mark()
	# forwarding, typed answers
	var hearts: Variant = _lr._call_api("get_hearts", ["fixture_npc"])
	var hearts_unknown: Variant = _lr._call_api("get_hearts", ["somebody_else"])
	var bday: Variant = _lr._call_api("is_birthday", ["fixture_npc"])
	var no_bday: Variant = _lr._call_api("is_birthday", ["somebody_else"])
	var fest: Variant = _lr._call_api("festival", [])
	t.expect(hearts == 3 and typeof(hearts) == TYPE_INT and hearts_unknown == 0 and bday == true and no_bday == false and typeof(bday) == TYPE_BOOL, "get_hearts -> int and is_birthday -> bool come from the manager: %s %s %s %s" % [str(hearts), str(hearts_unknown), str(bday), str(no_bday)])
	t.expect(fest == "fixture_fest" and typeof(fest) == TYPE_STRING, "festival() answers the String id of today's active festival (the manager's StringName becomes a String): %s (%s)" % [str(fest), type_string(typeof(fest))])
	fake.festival = &""
	var no_fest: Variant = _lr._call_api("festival", [])
	t.expect(no_fest == "" and typeof(no_fest) == TYPE_STRING and _lr._invoke_function(sid, "festival_is_on", []) == false, "with no festival on, festival() is the empty String and `api.festival() ~= \"\"` is false (the empty string is TRUTHY in Lua: compare, never test)")
	fake.festival = &"fixture_fest"
	# add_hearts: whole hearts, source = lua, a missing count adds nothing, a text count is read like the other int arguments
	fake.calls.clear()
	var ret: Variant = _lr._call_api("add_hearts", ["fixture_npc", 2])
	var forwarded: Array = fake.calls[0] if not fake.calls.is_empty() else []
	t.expect(ret == null and fake.calls.size() == 1 and forwarded == ["add_hearts", "fixture_npc", 2, &"lua"] and fake.hearts_by_npc["fixture_npc"] == 5, "add_hearts(npc, n) -> SocialManager.add_hearts(npc, n, &\"lua\") and answers nil: %s" % str(forwarded))
	fake.calls.clear()
	_lr._call_api("add_hearts", ["fixture_npc"])
	_lr._call_api("add_hearts", ["fixture_npc", "3"])
	t.expect(fake.calls == [["add_hearts", "fixture_npc", 0, &"lua"], ["add_hearts", "fixture_npc", 3, &"lua"]], "a missing count is 0 (the manager ignores it), \"3\" is 3: %s" % str(fake.calls))
	# from Lua: the same through content
	fake.hearts_by_npc["fixture_npc"] = 3
	var via_lua: Variant = _lr._invoke_function(sid, "bump", ["fixture_npc", 2])
	var stage_close: Variant = _lr._invoke_function(sid, "stage_of", ["fixture_npc"])
	var stage_far: Variant = _lr._invoke_function(sid, "stage_of", ["somebody_else"])
	t.expect(via_lua == 5 and stage_close == "close" and stage_far == "stranger" and _lr._invoke_function(sid, "is_bday", ["fixture_npc"]) == true and _lr._invoke_function(sid, "festival_now", []) == "fixture_fest", "from Lua: bump(npc, 2) reads 5 hearts, stage_of reads close / stranger, is_bday and festival_now answer: %s %s %s" % [str(via_lua), str(stage_close), str(stage_far)])
	t.expect_clean_since(mark, "the forwarded calls log no engine error or warning")
	# a manager that lacks a method is "no manager" for that function
	_t.tree.root.remove_child(fake)
	fake.free()
	var half := HalfSocial.new()
	half.name = SOCIAL
	_t.tree.root.add_child(half)
	var half_ok: bool = _lr._call_api("get_hearts", ["x"]) == 7 and _lr._call_api("is_birthday", ["x"]) == null and _lr._call_api("festival", []) == null and _lr._call_api("add_hearts", ["x", 1]) == null
	_t.tree.root.remove_child(half)
	half.free()
	t.check("api_functions_late_bound", hearts == 3 and bday == true and fest == "fixture_fest" and via_lua == 5 and half_ok, "with a fake SocialManager the four functions forward their arguments and type their answers (get_hearts 3, is_birthday true, festival fixture_fest, add_hearts(.., &\"lua\")); a manager without a method answers nil for it")


func _api_unknown_names() -> void:
	var t = _t
	_detach_real_social()
	_lr.reload_scripts()
	var mark: int = t.log_mark()
	var first: Variant = _lr._call_api("get_friendship", ["x"])
	var second: Variant = _lr._call_api("get_friendship", ["x"])
	var logged: Array = _lr._logged_once.keys().filter(func(m: String) -> bool: return m.contains("unknown Lua function `get_friendship`"))
	var message := str(logged[0]) if not logged.is_empty() else ""
	var lists_all := true
	for name in NEW_API:
		lists_all = lists_all and message.contains(name)
	for name in ["add_gold", "add_item", "remove_item", "set_flag", "get_flag", "has_flag", "has_item", "get_gold", "notification", "unlock_zone", "emit", "log", "offer_quest", "complete_quest"]:
		lists_all = lists_all and message.contains(name)
	t.check("api_unknown_names_log_once", first == null and second == null and logged.size() == 1 and lists_all, "an unknown function still answers nil and is logged once; the message lists the 14 old and the 4 new names: %s" % message)
	t.expect_clean_since(mark, "an unknown api function logs no engine error or warning")


# ------------------------------------------------------------------------------------------------ the real SocialManager (S-core)

## Takes a real SocialManager out of the tree (a test of "no manager" must not depend on the build state of S-core).
func _detach_real_social() -> void:
	if _detached != null:
		return
	var real: Node = _t.tree.root.get_node_or_null(SOCIAL)
	if real == null:
		return
	_detached_index = real.get_index()
	_detached = real
	_t.tree.root.remove_child(real)


func _attach_real_social() -> void:
	if _detached == null:
		return
	var real := _detached
	_t.tree.root.add_child(real)
	_t.tree.root.move_child(real, mini(_detached_index, _t.tree.root.get_child_count() - 1))
	_detached = null
	_t.expect(_t.tree.root.get_node_or_null(SOCIAL) == real and real.get_index() == _detached_index, "the real SocialManager is back in the tree at its old place (index %d)" % _detached_index)
