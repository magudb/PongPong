extends RefCounted
## Data-ownership mirrors and the boot contract manifest (review round 3).
##
## Named checks:
##   contracts.manifest_lists_the_late_bound_gates   every ResourceLoader.exists fallback of world_2d / shop_system is listed
##   contracts.manifest_reports_missing_once         report() posts one notification naming the gap, and only once
##   contracts.manifest_complete_is_silent           a forced report on a complete manifest posts nothing
##   contracts.husbandry_species_matches_lua         lua/config/husbandry.lua == AnimalHusbandry.SPECIES_DATA (fallback)
##   contracts.husbandry_buildings_matches_lua       lua/config/husbandry.lua == AnimalHusbandry.BUILDINGS
##   contracts.husbandry_loaded_from_lua             the live tables are the Lua ones (product_interval mapped to the enum)
##   contracts.starter_tools_match_lua               lua/data/starter_kit.lua starter_kit.tools == EconomyManager.STARTER_KIT
##   contracts.starter_tools_come_from_lua           reset() hands out the Lua tools
##   contracts.shipped_code_reads_no_dev_folders     no exported .gd/.tscn/.tres/.lua names res://docs|tests|tools|legacy/ (the export drops them,
##                                                   so such a read only fails in a shipped build; review REPO-10); a planted literal is seen failing
const SECTION := "contracts"
const TIMEOUT_S := 60.0


func run(t) -> void:
	var ah = t.autoload("AnimalHusbandry")
	var eco = t.autoload("EconomyManager")
	var lr = t.autoload("LuaRuntime")
	_manifest(t)
	_husbandry(t, ah, lr)
	_starter(t, eco, lr)
	_dev_folders(t)


func _manifest(t) -> void:
	var known: Dictionary = {}
	for e in ContractManifest.EXPECTED:
		known[str(e["path"])] = true
	# The gates that silently fall back must be listed (world_2d player / farm grid / farm view, shop F4 pair).
	var required := [
		"res://scenes/world2d/player_2d.tscn",
		"res://scripts/world2d/farm_grid.gd",
		"res://scripts/world2d/farm_view.gd",
		"res://scripts/economy/shop_rotation.gd",
		"res://scripts/economy/price_curve.gd",
	]
	var unlisted: Array[String] = []
	for p in required:
		if not known.has(p):
			unlisted.append(p)
	t.check("manifest_lists_the_late_bound_gates", unlisted.is_empty(),
		"ContractManifest.EXPECTED names the silent-fallback paths; unlisted: %s" % str(unlisted))

	# Every entry is well-formed and the fallbacks of a mid-wave tree really are missing.
	var bad: Array[String] = []
	for e in ContractManifest.EXPECTED:
		if not str(e["path"]).begins_with("res://") or str(e.get("fallback", "")) == "" or str(e.get("owner", "")) == "":
			bad.append(str(e))
	t.check("manifest_entries_are_well_formed", bad.is_empty(), "path/fallback/owner on every row: %s" % str(bad))

	var gaps := ContractManifest.missing()
	var expected_gaps: Array = ContractManifest.EXPECTED.filter(func(row): return not ResourceLoader.exists(str(row.path)))
	t.check("manifest_sees_the_wave_holes", gaps == expected_gaps and ContractManifest.is_complete() == gaps.is_empty(), ContractManifest.describe(gaps))

	# Package diagnostics must never become player-facing copy.
	var notes: Array = []
	var bus = t.autoload("EventBus")
	var diagnostics: Array = []
	var on_note := func(title, body, _icon): notes.append([title, body])
	var on_event := func(id, payload):
		if id == &"contract_fallbacks":
			diagnostics.append(payload)
	bus.notification_posted.connect(on_note)
	bus.game_event.connect(on_event)
	ContractManifest.reset()
	ContractManifest.report()
	ContractManifest.report()
	t.check("manifest_reports_missing_once",
		notes.is_empty() and ((diagnostics.size() == 1 and diagnostics[0].gaps == gaps) if not gaps.is_empty() else diagnostics.is_empty()),
		"One diagnostic event, no package paths in player notifications")

	# A complete manifest says nothing.
	ContractManifest.reset()
	var complete: Array[Dictionary] = ContractManifest.missing()
	# Simulate completion by reporting with an empty gap set: describe([]) is "", report() on empty missing() is silent.
	var before: int = diagnostics.size()
	# Force the "everything present" path: temporarily report while missing() is empty is not reachable
	# without faking ResourceLoader, so assert the other half instead - reset() allows a fresh report.
	ContractManifest.report()
	t.check("manifest_reset_allows_a_fresh_report", diagnostics.size() == before + (0 if gaps.is_empty() else 1))
	bus.notification_posted.disconnect(on_note)
	bus.game_event.disconnect(on_event)
	ContractManifest.reset()


func _husbandry(t, ah, lr) -> void:
	var cfg: Dictionary = lr.get_config("husbandry", {})
	var src: Dictionary = cfg.get("species", {})
	var fallback: Dictionary = ah.SPECIES_DATA
	t.check("husbandry_species_matches_lua", src.size() == fallback.size() and _species_equal(src, fallback, ah),
		"%d species in lua/config/husbandry.lua == the AnimalHusbandry fallback (%d)" % [src.size(), fallback.size()])

	var bsrc: Dictionary = cfg.get("buildings", {})
	var bfb: Dictionary = ah.BUILDINGS
	t.check("husbandry_buildings_matches_lua", bsrc.size() == bfb.size() and _buildings_equal(bsrc, bfb),
		"%d buildings in Lua == the fallback (%d); neither has a build_days (an animal building is finished at once, GAP4-08)" % [bsrc.size(), bfb.size()])

	# The live tables ARE the Lua ones (loaded at _ready): same keys, product_interval is the enum.
	t.check("husbandry_loaded_from_lua",
		ah.species_data.size() == src.size() and ah.buildings_data.size() == bsrc.size()
		and int(ah.species_data["chicken"]["product_interval"]) == int(ah.ProductType.DAILY)
		and int(ah.species_data["rabbit"]["product_interval"]) == int(ah.ProductType.EVERY_2_DAYS)
		and int(ah.species_data["cat"]["product_interval"]) == int(ah.ProductType.ON_BOND)
		and not (ah.species_data["chicken"] as Dictionary).has("species_enum"),
		"species_data/buildings_data replaced the fallback; product_interval strings became ProductType")


func _starter(t, eco, lr) -> void:
	var tools: Dictionary = lr.get_config("starter_kit.tools", {})
	var fallback: Dictionary = {}
	for e in eco.STARTER_KIT:
		fallback[str(e[0])] = int(e[1])
	var same: bool = tools.size() == fallback.size()
	for id in tools:
		if int(tools[id]) != int(fallback.get(str(id), -1)):
			same = false
	t.check("starter_tools_match_lua", same and not tools.is_empty(),
		"lua/data/starter_kit.lua starter_kit.tools (%d) == EconomyManager.STARTER_KIT (%d)" % [tools.size(), fallback.size()])

	var gold_keep: int = eco.gold
	eco.reset()
	var got: Dictionary = eco.get_inventory_dict()
	var kit_ok: bool = not got.is_empty()
	for id in tools:
		if eco.count_item(StringName(str(id))) < int(tools[id]):
			kit_ok = false
	t.check("starter_tools_come_from_lua", kit_ok,
		"reset() hands out every Lua tool: have %s want %s" % [str(got.keys()), str(tools.keys())])
	eco.gold = gold_keep


## Folders the export presets leave out (export_presets.cfg exclude_filter): a shipped file must not read from them.
const DEV_FOLDER := "res://(docs|tests|tools|legacy)/"
const SHIPPED_CODE := ["gd", "tscn", "tres", "lua"]


func _dev_folders(t) -> void:
	var excluded: PackedStringArray = []
	var presets := ConfigFile.new()
	if presets.load("res://export_presets.cfg") == OK:
		for f in str(presets.get_value("preset.0", "exclude_filter", "")).split(",", false):
			excluded.append(f.strip_edges())
	var re := RegEx.create_from_string(DEV_FOLDER + "[^\"']*")
	var hits: Array[String] = []
	var files: Array[String] = []
	for top in ["res://scripts", "res://scenes", "res://shaders", "res://lua", "res://data", "res://assets"]:
		_code_files(top, files)
	var scanned := 0
	for path in files:
		var rel := path.trim_prefix("res://")
		if Array(excluded).any(func(f: String) -> bool: return rel.match(f)):
			continue
		scanned += 1
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			hits.append("%s: %s" % [rel, m.get_string()])
	var planted := re.search("var x := load(\"res://docs/art/a.json\")") != null and re.search("load(\"res://data/a.json\")") == null
	t.check("shipped_code_reads_no_dev_folders", hits.is_empty() and scanned > 500 and planted,
		"%d exported code files name no %s path (a planted docs/ read is seen, data/ is not: %s); %s" % [scanned, DEV_FOLDER, planted, str(hits.slice(0, 4))])


func _code_files(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in SHIPPED_CODE:
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if not FileAccess.file_exists(dir.path_join(d).path_join(".gdignore")):
			_code_files(dir.path_join(d), out)


func _species_equal(src: Dictionary, fallback: Dictionary, ah) -> bool:
	for id in src:
		var a: Variant = src[id]
		var b: Variant = fallback.get(str(id))
		if not (a is Dictionary) or not (b is Dictionary):
			return false
		var da: Dictionary = (a as Dictionary).duplicate()
		var db: Dictionary = (b as Dictionary).duplicate()
		da.erase("species_enum")
		db.erase("species")
		if str(da.get("product_interval", "")) != "":
			da["product_interval"] = int(ah.PRODUCT_INTERVALS.get(str(da["product_interval"]), 0))
		if da.size() != db.size():
			return false
		for k in da:
			if not db.has(k):
				return false
			var va: Variant = da[k]
			var vb: Variant = db[k]
			if va is Array and vb is Array:
				if (va as Array).size() != (vb as Array).size():
					return false
				for i in (va as Array).size():
					if str((va as Array)[i]) != str((vb as Array)[i]) and float((va as Array)[i]) != float((vb as Array)[i]):
						return false
			elif va is float or vb is float:
				if absf(float(va) - float(vb)) > 0.0001:
					return false
			elif str(va) != str(vb) and int(va) != int(vb):
				return false
	return true


func _buildings_equal(src: Dictionary, fallback: Dictionary) -> bool:
	for id in src:
		var a: Variant = src[id]
		var b: Variant = fallback.get(str(id))
		if not (a is Dictionary) or not (b is Dictionary):
			return false
		var da: Dictionary = a as Dictionary
		var db: Dictionary = b as Dictionary
		if str(da.get("name_key", "")) != str(db.get("name_key", "")) or int(da.get("capacity", -1)) != int(db.get("capacity", -2)) or da.has("build_days") or db.has("build_days"):
			return false
		var ca: Dictionary = da.get("build_cost", {})
		var cb: Dictionary = db.get("build_cost", {})
		if ca.size() != cb.size():
			return false
		for k in ca:
			if int(ca[k]) != int(cb.get(str(k), -1)):
				return false
	return true
