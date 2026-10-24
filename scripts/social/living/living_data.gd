class_name LivingData
extends RefCounted
## LC1 declarative proposals only. No state, errands, selector, routine override or transaction.
## Readers return shared read-only Lua tables, just like SocialData. No synthetic profile fallback.

const AUDITED_IDS := [
	"appraiser_fru_ugle", "baker_maja", "bathkeeper_sofus", "beekeeper_birk", "bertil", "bodil",
	"carpenter_brumme", "cat_morfar_mis", "clerk_fjerpen", "cub_bamse", "fairy_builder",
	"fairy_furnisher", "fairy_king", "fairy_lily", "fairy_tailor", "fairy_wizard", "farmer_rosa",
	"fiddler_strimmel", "gardener_hoppe", "ghostfam_blund", "ghostfam_dyne", "ghostfam_gnist",
	"ghostfam_silke", "guard_oak", "innkeeper_kvak", "lamplighter_kiki", "mapseller_natteblik",
	"mayor_lyra", "merchant_pip", "penguin_postman", "pippin_boegeknop", "postman_pip", "rasmus", "smith_thorin",
]
const GOAL_KINDS := ["role", "personal", "connect", "reconcile"]
const RESOLUTION_KINDS := ["autonomous", "attendance", "clarification"]
const COPY_PATH := "res://localization/living_characters.csv"
const PROPOSAL_PATH := "res://lua/social/living_citizens.lua"


static func profiles() -> Dictionary:
	return LuaData.dict(Svc.lua_config("living_citizens", {}))


static func profile(npc: String) -> Dictionary:
	return LuaData.dict(profiles().get(npc, {}))


## Omitted/null reads runtime. Explicit {} is empty and MUST report all missing citizens.
## Stable diagnostic prefixes: coverage:missing/unknown, schema:<path>:<rule>.
## Pure filesystem/config inspection, never player/world-state creation. No runtime is required.
static func validate(candidate: Variant = null) -> Array[String]:
	var errors: Array[String] = []
	var rows := profiles() if candidate == null else LuaData.dict(candidate)
	var copy := _copy_rows(errors)
	var identities := {}
	var goal_ids := {}
	for npc in AUDITED_IDS:
		if not rows.has(npc):
			errors.append("coverage:missing:" + npc)
	for npc in rows:
		var path := str(npc)
		if npc not in AUDITED_IDS:
			errors.append("coverage:unknown:" + path)
		var row := LuaData.dict(rows[npc])
		var id := str(row.get("id", ""))
		_require(errors, id == path and id != "" and not identities.has(id), path, "id")
		identities[id] = true
		_require(errors, row.get("authorship") == "original_proposal", path, "authorship")
		for field in ["role", "age", "family", "twin", "unlock", "routine", "name_key", "home_area", "partner", "hearts"]:
			_require(errors, not row.has(field), path, "identity_override:" + field)
		for field in ["purpose_key", "aspiration_key"]:
			_key(errors, row.get(field), path + "." + field, copy)
		for field in ["identity_source", "availability_source"]:
			_source(errors, row.get(field), path + "." + field)
		var values := LuaData.dict(row.get("values"))
		_require(errors, values.size() >= 2 and values.size() <= 4, path, "values_bound")
		for value in values:
			_require(errors, str(value) != "" and _whole(values[value], 1, 5), path + ".values." + str(value), "weight")
		var ties := LuaData.arr(row.get("ties"))
		_require(errors, ties.size() >= 1 and ties.size() <= 8, path, "ties_bound")
		var targets := {}
		for i in ties.size():
			var tie := LuaData.dict(ties[i])
			var tp := path + ".ties." + str(i)
			var target := str(tie.get("target", ""))
			_require(errors, target in AUDITED_IDS and target != path and not targets.has(target), tp, "target")
			targets[target] = true
			var provenance := str(tie.get("provenance", ""))
			_require(errors, provenance in ["established", "proposed"], tp, "provenance")
			_source(errors, tie.get("source"), tp)
			if provenance == "proposed":
				_require(errors, tie.get("source") == PROPOSAL_PATH, tp, "proposal_source")
			_key(errors, tie.get("reason_key"), tp, copy)
		var goals := LuaData.arr(row.get("goals"))
		_require(errors, goals.size() >= 1 and goals.size() <= 4, path, "goals_bound")
		for i in goals.size():
			_goal(errors, LuaData.dict(goals[i]), path + ".goals." + str(i), path, values, targets, goal_ids, copy)
	return errors


static func _goal(errors: Array[String], goal: Dictionary, path: String, npc: String, values: Dictionary, targets: Dictionary, ids: Dictionary, copy: Dictionary) -> void:
	var id := str(goal.get("id", ""))
	_require(errors, id.begins_with("lc_" + npc + "_") and not ids.has(id), path, "id")
	ids[id] = true
	_require(errors, goal.get("kind") in GOAL_KINDS, path, "kind")
	_require(errors, values.has(goal.get("value")), path, "value")
	_require(errors, _whole(goal.get("weight"), 1, 5), path, "weight")
	_require(errors, _whole(goal.get("cooldown_days"), 1, 14), path, "cooldown_days")
	_require(errors, _whole(goal.get("expires_days"), 1, 7), path, "expires_days")
	var eligible := LuaData.dict(goal.get("eligible"))
	_require(errors, eligible == {"free_time": true, "existing_availability": true}, path, "eligibility")
	_key(errors, goal.get("text_key"), path, copy)
	if goal.get("kind") in ["connect", "reconcile"]:
		_require(errors, targets.has(goal.get("target")), path, "target")
	var trigger := str(goal.get("trigger", ""))
	_require(errors, trigger == "none" or (npc == "smith_thorin" and trigger == "future_committed_mining_help"), path, "trigger")
	_require(errors, _whole(goal.get("currency"), 0, 0), path, "currency")
	_require(errors, typeof(goal.get("resources")) == TYPE_DICTIONARY, path, "resources")
	var resources := LuaData.dict(goal.get("resources"))
	_require(errors, resources.size() <= 4, path, "resources_bound")
	for item in resources:
		var runtime := Svc.node("LuaRuntime")
		var exists := runtime != null and not LuaData.dict(runtime.call("get_item_def", str(item))).is_empty()
		_require(errors, exists and _whole(resources[item], 1, 4), path, "resource:" + str(item))
	if npc in ["baker_maja", "beekeeper_birk", "smith_thorin"]:
		_require(errors, resources.is_empty(), path, "pilot_zero_items")
	var resolutions := LuaData.arr(goal.get("resolutions"))
	_require(errors, resolutions.size() >= 2 and resolutions.size() <= 3, path, "resolutions_bound")
	var kinds := {}
	for i in resolutions.size():
		var resolution := LuaData.dict(resolutions[i])
		var rid := str(resolution.get("id", ""))
		_require(errors, rid != "" and not kinds.has(rid), path, "resolution_id")
		var kind := str(resolution.get("kind", ""))
		_require(errors, kind in RESOLUTION_KINDS, path, "resolution_kind")
		kinds[rid] = kind
		_key(errors, resolution.get("text_key"), path + ".resolution." + rid, copy)
	_require(errors, kinds.get(goal.get("fallback"), "") == "autonomous", path, "fallback")
	_require(errors, kinds.get(goal.get("reconciliation"), "") == "clarification", path, "reconciliation")


static func _whole(value: Variant, low: int, high: int) -> bool:
	if typeof(value) not in [TYPE_FLOAT, TYPE_INT]:
		return false
	var number := float(value)
	return is_finite(number) and number == floor(number) and number >= low and number <= high


static func _require(errors: Array[String], condition: bool, path: String, rule: String) -> void:
	if not condition:
		errors.append("schema:" + path + ":" + rule)


static func _key(errors: Array[String], key: Variant, path: String, copy: Dictionary) -> void:
	_require(errors, typeof(key) == TYPE_STRING and copy.has(key), path, "localization")


static func _source(errors: Array[String], source: Variant, path: String) -> void:
	_require(errors, typeof(source) == TYPE_STRING and str(source).begins_with("res://") and FileAccess.file_exists(str(source)), path, "source")


## Validate actual shipped bilingual CSV, not tr(key)==key (which can hide fallback-language errors).
static func _copy_rows(errors: Array[String]) -> Dictionary:
	var rows := {}
	var file := FileAccess.open(COPY_PATH, FileAccess.READ)
	if file == null:
		errors.append("schema:copy:missing")
		return rows
	_require(errors, file.get_csv_line() == PackedStringArray(["keys", "da", "en"]), "copy", "header")
	while not file.eof_reached():
		var cells := file.get_csv_line()
		if cells.size() == 1 and cells[0] == "":
			continue
		if cells.size() != 3:
			errors.append("schema:copy:columns")
			continue
		var valid := cells[0] != "" and cells[1].strip_edges() != "" and cells[2].strip_edges() != "" and not rows.has(cells[0])
		_require(errors, valid, "copy." + cells[0], "bilingual_or_duplicate")
		if valid:
			rows[cells[0]] = true
	return rows
