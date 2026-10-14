extends SceneTree
## Audit the effective runtime catalogs, including worktree-local additions.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var strict := "--strict" in OS.get_cmdline_user_args()
	var details := "--details" in OS.get_cmdline_user_args()
	var lua := root.get_node("LuaRuntime")
	var report := {"characters": [], "skins": [], "npcs": [], "items": [], "tiles": [], "props": [], "references": [], "failures": []}
	for id in DirAccess.get_directories_at("res://assets/isometric_characters"):
		var path := "res://assets/isometric_characters/" + id + "/animations.json"
		if not FileAccess.file_exists(path):
			continue
		var entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var missing: Array[String] = []
		var animations: Dictionary = entry.get("animations", {})
		for clip in animations:
			var file := path.get_base_dir() + "/" + str(animations[clip].get("sheet", ""))
			if not ResourceLoader.exists(file):
				missing.append(file)
		if not missing.is_empty():
			report["failures"].append("character sheets: " + id)
		if not entry.has("illustration"):
			report["failures"].append("character lacks drawn source: " + id)
		if not ResourceLoader.exists(path.get_base_dir() + "/portrait.webp") and not ResourceLoader.exists("res://assets/portraits/" + id + ".webp"):
			report["failures"].append("character portrait: " + id)
		report["characters"].append({"id": id, "clips": animations.size(), "illustration": entry.get("illustration", ""), "missing_sheets": missing})
	var characters := CharacterCatalog.data()
	for skin_id in characters.get("skins", {}):
		var skin: Dictionary = characters["skins"][skin_id]
		var head := str(skin.get("visual", ""))
		var resolved := CharacterCatalog.resolve(head)
		report["skins"].append({"id": skin_id, "requested": head, "resolved": resolved, "retired": skin.get("retired", false)})
		if resolved.is_empty():
			report["failures"].append("skin cannot resolve: " + str(skin_id))
		elif not bool(skin.get("retired", false)) and resolved != head and resolved != head.trim_suffix("_base"):
			report["failures"].append("active hero uses another character: " + str(skin_id) + " -> " + resolved)
	var npcs: Dictionary = lua.get_npcs()
	for id in npcs:
		var visual := str(npcs[id].get("visual", ""))
		report["npcs"].append({"id": id, "requested": visual, "resolved": CharacterCatalog.resolve(visual)})
		if CharacterCatalog.resolve(visual) != visual:
			report["failures"].append("NPC uses a stand-in: " + str(id))
	for section in ["animals", "enemies"]:
		for id in characters.get(section, {}):
			var row: Dictionary = characters[section][id]
			for key in ["baby", "adult", "visual"]:
				if not row.has(key):
					continue
				var visual := str(row[key])
				var resolved := CharacterCatalog.resolve(visual)
				report["references"].append({"group": section, "id": id, "view": key, "requested": visual, "resolved": resolved})
				if resolved != visual:
					report["failures"].append(section + " uses a stand-in: " + str(id) + "." + str(key))
	var ids: Array = lua.get_all_item_ids()
	ids.sort()
	for id in ids:
		var def: Dictionary = lua.get_item_def(id)
		var item := {"id": id, "category": def.get("category", ""), "name_key": def.get("name_key", ""), "rarity": def.get("rarity", "normal"),
			"path": TTItemIcon.resolve_path(id, def.get("rarity", "normal")), "catalog_path": ArtCatalog.icon_path(StringName(id))}
		if details:
			item["definition"] = def
		report["items"].append(item)
		if item["path"] == "" or item["catalog_path"] == "":
			report["failures"].append("item picture: " + str(id))
	var terrain_ids := ArtCatalog.terrain_manifest_ids()
	# Include requested IDs as well as authored ones, so a missing manifest row
	# cannot disappear from this audit. Dynamic farm/home surfaces are included
	# by their additive manifests; map ground uses the actual builder resolver.
	for id in AreaTileSet.ISO_TERRAINS + AreaTileSet.ORTHO_TERRAINS:
		if str(id) not in terrain_ids:
			terrain_ids.append(str(id))
	var map_props: Array[String] = []
	for filename in DirAccess.get_files_at("res://data/maps"):
		if not filename.ends_with(".map"):
			continue
		var map := AreaMap.load_file("res://data/maps/" + filename)
		if map == null:
			report["failures"].append("cannot audit map: " + filename)
			continue
		# Load after autoload startup: a -s driver compiles before EventBus exists.
		var resolver = load("res://scripts/world2d/iso_area.gd").new()
		resolver.map = map
		resolver.projection = map.projection
		for y in map.height:
			for x in map.width:
				var id := str(resolver.terrain_for_char(map.ground_at(Vector2i(x, y)), Vector2i(x, y)))
				if not id.is_empty() and id not in terrain_ids:
					terrain_ids.append(id)
		resolver.free()
		for row in map.props.values():
			var id := str(row.get("prop", ""))
			if not id.is_empty() and id not in map_props:
				map_props.append(id)
	terrain_ids.sort()
	for id in terrain_ids:
		var art := ArtCatalog.terrain(StringName(id))
		report["tiles"].append({"id": id, "path": (art["texture"] as Texture2D).resource_path, "real": art["real"], "cell": [art["cell"].x, art["cell"].y], "variants": [art["variants"].x, art["variants"].y]})
		if not art["real"] or not (art["texture"] as Texture2D).resource_path.contains("/drawn_"):
			report["failures"].append("tile lacks painted material: " + id)
	var prop_ids := GameData.prop_ids()
	for id in ArtCatalog.prop_manifest_ids() + map_props:
		if id not in prop_ids:
			prop_ids.append(id)
	prop_ids.sort()
	for id in prop_ids:
		var art := ArtCatalog.prop(StringName(id))
		report["props"].append({"id": id, "path": (art["texture"] as Texture2D).resource_path, "real": art["real"]})
		if not art["real"]:
			report["failures"].append("prop picture: " + id)
	if details:
		report["character_data"] = characters
	report["result"] = "pass" if report["failures"].is_empty() else "fail"
	var out := "res://docs/art/drawn/coverage.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			out = arg.trim_prefix("--report=")
	var file := FileAccess.open(out, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	print("ART COVERAGE ", report["characters"].size(), " characters, ", report["items"].size(), " items, ", report["tiles"].size(), " tiles, ", report["props"].size(), " props; ", out)
	print("ART COVERAGE ", report["result"], ": ", report["failures"].size(), " gaps")
	quit(1 if strict and not report["failures"].is_empty() else 0)
