extends RefCounted
## Provenance/placement regressions; visual judgment is recorded in docs/art/style-audit.
const SECTION := "art_style_consistency"
const TIMEOUT_S := 180.0
const PACK := "res://assets/iso_props/zz_painted_consistency/"
const FURN := "res://assets/iso_props/furniture/"
const SEASONS := "res://assets/iso_props/farm_dress/"
const STORY := "res://assets/iso_props/forest_mother/"
const TECHNICAL := ["boss_arena_ring", "crown_spark", "dig_glimmer", "eyes_glow", "fire_flame", "fire_flame_f1", "fire_flame_f2",
	"firefly_dot", "fx_heal_sparkle", "fx_hit_spark", "halo_amber", "halo_violet", "hulen_eyes", "lantern_light",
	"mist_patch_a", "mist_patch_b", "paw_prints", "pond_ripple", "pond_sheen", "shadow_soft", "telegraph_line",
	"telegraph_ring_l", "telegraph_ring_m", "telegraph_ring_s", "unique_glimmer"]

func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func run(t) -> void:
	ArtCatalog.reset()
	var manifest := _json(PACK + "props.json")
	var before := _json("res://docs/art/style-audit/catalog-before.json")
	var missing: Array[String] = []
	var prototype: Array[String] = []
	var ids := ArtCatalog.prop_manifest_ids()
	for id in GameData.prop_ids():
		if str(id) not in ids:
			ids.append(str(id))
	for row in before["props"]:
		if str(row["id"]) not in ids:
			missing.append(str(row["id"]))
	for id in ids:
		var art := ArtCatalog.prop(StringName(id))
		var path := (art["texture"] as Texture2D).resource_path
		if not bool(art["real"]):
			missing.append(id)
		if not path.contains("/painted_") and not path.contains("/drawn") and not path.begins_with(PACK) and not path.begins_with(STORY) and not path.begins_with(SEASONS) and id not in TECHNICAL:
			prototype.append(id)
	t.check("effective_physical_props_painted", missing.is_empty() and prototype.is_empty(),
		"357 prior IDs preserved, %d current prop IDs checked; physical props use approved paintings/materials and intentional masks are explicit: %s %s" % [ids.size(), missing, prototype])
	var ledger := _json("res://docs/art/style-audit/current/approval.json")["reviewed_assets"] as Dictionary
	var unreviewed: Array[String] = []
	for id in ids:
		var path: String = (ArtCatalog.prop(StringName(id))["texture"] as Texture2D).resource_path.trim_prefix("res://")
		if not ledger.has(path) or ledger[path].get("disposition") == "retained-unselected":
			unreviewed.append(str(id))
	for theme in [&"farm", &"hyggebyen", &"forest", &"treetop"]:
		var art := ArtCatalog.backdrop(theme)
		for key in ["sky", "far"]:
			var path: String = (art[key] as Texture2D).resource_path.trim_prefix("res://")
			if not ledger.has(path) or ledger[path].get("disposition") == "retained-unselected":
				unreviewed.append("%s %s" % [theme, key])
	t.check("selected_art_is_reviewed", unreviewed.is_empty(), "effective props and all outdoor sky/far layers have explicit visual review evidence: %s" % [unreviewed])
	var result: Array = []
	var exit_code := OS.execute("python3", PackedStringArray([ProjectSettings.globalize_path("res://tools/art/drawn/style_audit_current.py"), "--check"]), result, true)
	t.check("reviewed_snapshot_current", exit_code == 0, str(result).left(1200))
	var original := _json("res://assets/iso_props/props.json")
	for folder in ["farm", "features", "city"]:
		original.merge(_json("res://assets/iso_props/%s/props.json" % folder), true)
	var count := 0
	for id in manifest:
		if str(id).begins_with("_"):
			continue
		count += 1
		var record: Dictionary = manifest[id]
		var art := ArtCatalog.prop(StringName(id))
		var texture: Texture2D = art["texture"]
		var same_fp: bool = not original.has(id) or record["footprint"] == original[id]["footprint"]
		var source_exists := FileAccess.file_exists("res://" + str(record["illustration"]))
		var glow_ok := not record.has("glow") or not (art["glow"] as Dictionary).is_empty()
		t.check("installed_%s" % id, texture.resource_path == PACK + str(record["file"])
			and texture.get_size() == Vector2(record["size"][0], record["size"][1]) and same_fp and source_exists and glow_ok,
			"effective painted texture, source, dimensions, original footprint and optional light resolve")
	t.check("replacement_scope", count >= 100, "%d repaired props, structural surfaces and parallax entries" % count)
	var far: Texture2D = ArtCatalog.backdrop(&"farm")["far"]
	t.check("farm_parallax_painted", far.resource_path == PACK + "backdrop_farm_far.webp", "farm horizon shares the approved tree painting")
	var layout := _json("res://tools/art/drawn/consistency_layout.json")["items"] as Dictionary
	var furniture := _json(FURN + "furniture.json")["items"] as Dictionary
	var bad: Array[String] = []
	for id in layout:
		var old: Dictionary = layout[id]
		var current: Dictionary = furniture.get(id, {})
		for key in ["footprint", "layer", "template", "rarity", "interact", "surface_slots"]:
			if current.get(key) != old.get(key):
				bad.append("%s.%s" % [id, key])
		for rotation in old["rot"]:
			for key in ["size", "pivot", "footprint", "ysort", "interact_from", "interact_anchor"]:
				if current["rot"][rotation].get(key) != old["rot"][rotation].get(key):
					bad.append("%s r%s.%s" % [id, rotation, key])
	t.check("furniture_gameplay_contracts", furniture.size() == layout.size() and bad.is_empty(), "all 130 IDs, placement anchors and gameplay fields preserved; %s" % str(bad.slice(0, 5)))

func run_windowed(t) -> void:
	var furniture := _json(FURN + "furniture.json")["items"] as Dictionary
	var entries: Array[Dictionary] = []
	for id in furniture:
		for rotation in furniture[id]["rot"]:
			entries.append({"label": "%s r%s" % [id, rotation], "path": FURN + str(furniture[id]["rot"][rotation]["file"])})
	await _pages(t, "furniture", entries)
	entries.clear()
	var props := _json(PACK + "props.json")
	for id in props:
		if not str(id).begins_with("_"):
			entries.append({"label": id, "path": PACK + str(props[id]["file"])})
	await _pages(t, "props", entries)
	entries.clear()
	for id in furniture:
		entries.append({"label": id, "path": ArtCatalog.icon_path(StringName(id))})
	var materials := _json("res://docs/art/style-audit/material-ids.json")["ids"] as Array
	for id in materials:
		entries.append({"label": id, "path": ArtCatalog.icon_path(StringName(id))})
	await _pages(t, "icons", entries)
	await _worlds(t)

func _worlds(t) -> void:
	var manager: Node = t.root.get_node("GameManager")
	manager.start_new_game("Style audit", 0)
	var world: WorldRoot2D = load("res://scenes/main/world.tscn").instantiate()
	t.root.add_child(world)
	await t.frames(45)
	for area in [&"farm", &"hyggebyen", &"traetoppen", &"moerkeskoven"]:
		world._enter(area, &"default")
		await t.frames(20)
		var camera: Camera2D = world.player.get("camera")
		camera.zoom = Vector2.ONE * (0.55 if area != &"traetoppen" else 0.4)
		camera.reset_smoothing()
		for hour in [11.0, 21.0]:
			world.day_night.override_hour = hour
			world.day_night.snap()
			world.area.set_night_factor(world.day_night.glow_factor)
			await t.frames(8)
			var capture: Image = await t.capture("world_%s_%s" % [area, "day" if hour < 18.0 else "night"])
			if capture != null:
				t.expect_not_blank(capture, Rect2i(0, 0, 1280, 720), "%s at hour %.0f renders" % [area, hour])
	world.free()
	await t.frames(2)

func _pages(t, family: String, entries: Array[Dictionary]) -> void:
	for start in range(0, entries.size(), 20):
		var host := Control.new()
		host.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.root.add_child(host)
		var paper := ColorRect.new()
		paper.color = Color("eee7d8")
		paper.size = Vector2(1280, 720)
		host.add_child(paper)
		var heading := Label.new()
		heading.position = Vector2(15, 5)
		heading.text = "Imported %s · %d–%d of %d" % [family, start + 1, mini(start + 20, entries.size()), entries.size()]
		heading.add_theme_color_override("font_color", Color("2b2340"))
		host.add_child(heading)
		for index in range(start, mini(start + 20, entries.size())):
			var slot := index - start
			var at := Vector2((slot % 5) * 256 + 10, floorf(float(slot) / 5.0) * 168 + 40)
			var image := TextureRect.new()
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image.texture = load(str(entries[index]["path"])) as Texture2D
			image.position = at
			image.size = Vector2(236, 134)
			host.add_child(image)
			var label := Label.new()
			label.position = at + Vector2(0, 136)
			label.text = str(entries[index]["label"])
			label.add_theme_font_size_override("font_size", 15)
			label.add_theme_color_override("font_color", Color("2b2340"))
			host.add_child(label)
		await t.frames(2)
		var page := floori(float(start) / 20.0) + 1
		var capture: Image = await t.capture("%s_%02d" % [family, page])
		if capture != null:
			t.expect_not_blank(capture, Rect2i(10, 40, 1260, 650), "imported %s page %d renders" % [family, page])
		host.free()
