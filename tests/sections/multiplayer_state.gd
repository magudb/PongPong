extends RefCounted
## Section multiplayer_state (package MP3-player-state): PlayerState rows, save v3 shape,
## and the single-player equivalence contract (one row == the old global backpack/quest log).
const SECTION := "multiplayer_state"
const TIMEOUT_S := 60.0


func run(t) -> void:
	_test_defaults(t)
	_test_roundtrip(t)
	_test_reset_profile(t)
	_test_save_shape(t)
	_test_runtime_save(t)
	await _test_world_lifetime(t)


func _test_defaults(t) -> void:
	var p := PlayerState.new()
	t.check("defaults", p.player_id == &"p0" and p.peer_id == 1 and p.gold == PlayerState.DEFAULT_STARTING_GOLD
		and p.inventory.is_empty() and p.name == "" and p.player_pos == Vector2.ZERO,
		"%s gold=%d inv=%d" % [p.player_id, p.gold, p.inventory.size()])
	var g := PlayerState.new(&"p2", 3)
	t.check("slots", g.player_id == &"p2" and g.peer_id == 3, "id=%s peer=%d" % [g.player_id, g.peer_id])


func _test_roundtrip(t) -> void:
	var p := PlayerState.new(&"p1", 2)
	p.reset_profile("Frede", 1, &"fairy_dusk")
	p.gold = 777
	p.inventory.append({"id": &"wood", "amount": 12, "meta": {}})
	p.equipment[&"tool_hoe"] = &"hoe_iron"
	p.quests = {"active": {"lost_cat": {}}}
	p.wardrobe = {"equipped": {"hat": "hat_wizard"}}
	p.half_hearts = 6
	p.oil = 40.0
	p.player_pos = Vector2(12, -8)
	p.area = &"farm"
	var row := p.to_dict()
	var q := PlayerState.new()
	var ok: bool = q.from_dict(row)
	t.check("roundtrip", ok and q.player_id == &"p1" and q.peer_id == 2 and q.name == "Frede"
		and q.character_type == 1 and q.character_skin == &"fairy_dusk" and q.gold == 777
		and q.inventory.size() == 1 and q.inventory[0]["id"] == &"wood" and q.inventory[0]["amount"] == 12
		and q.equipment.get(&"tool_hoe") == &"hoe_iron" and q.half_hearts == 6
		and q.area == &"farm" and q.player_pos == Vector2(12, -8)
		and q.quests.has("active") and q.wardrobe.has("equipped"),
		"row %s" % str(row.keys()))
	var empty := PlayerState.new()
	t.check("from_dict_needs_id", not empty.from_dict({"gold": 1}), "a row without id is refused")


func _test_reset_profile(t) -> void:
	var p := PlayerState.new(&"p3", 4)
	p.gold = 9
	p.inventory.append({"id": &"x", "amount": 1, "meta": {}})
	p.reset_profile("Ida", 2, &"hobbit_pip")
	t.check("reset_profile", p.name == "Ida" and p.character_type == 2 and p.character_skin == &"hobbit_pip"
		and p.gold == PlayerState.DEFAULT_STARTING_GOLD and p.inventory.is_empty() and p.quests.is_empty(),
		"gold=%d inv=%d" % [p.gold, p.inventory.size()])


func _test_save_shape(t) -> void:
	# The save row is JSON-safe and round-trips through a real stringify (RM5).
	var p := PlayerState.new()
	p.reset_profile("Test", 0, &"animal_fox")
	var row := p.to_dict()
	var text := JSON.stringify(row)
	var parsed: Variant = JSON.parse_string(text)
	t.check("save_shape", parsed is Dictionary and (parsed as Dictionary).get("id") == "p0"
		and (parsed as Dictionary).has("gold") and (parsed as Dictionary).has("inventory")
		and (parsed as Dictionary).has("equipment") and (parsed as Dictionary).has("quests")
		and (parsed as Dictionary).has("wardrobe") and (parsed as Dictionary).has("player_pos"),
		"JSON keys %s" % str((parsed as Dictionary).keys() if parsed is Dictionary else parsed))


func _test_runtime_save(t) -> void:
	var p := PlayerState.new()
	var quest = preload("res://scripts/autoload/quest_manager.gd").QuestRuntime.new()
	quest.id = &"profile_probe"
	p.quests = {"active": {"profile_probe": quest}, "flags": {"def_profile_probe": {"title": "definition"}, "progress": 3}}
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(p.to_dict()))
	t.check("quest_runtimes_save_as_plain_records", parsed.quests.active.profile_probe is Dictionary
		and parsed.quests.active.profile_probe.id == "profile_probe" and not parsed.quests.flags.has("def_profile_probe")
		and parsed.quests.flags.progress == 3 and p.quests.active.profile_probe == quest and p.quests.flags.has("def_profile_probe"))


func _test_world_lifetime(t) -> void:
	if not await t.start_world():
		return
	var host := PlayerRegistry.state(&"p0")
	var guest := PlayerRegistry.state(&"p1")
	host.gold = 711
	guest.gold = 99
	await t.clear_scene()
	t.check("profile_rows_survive_world_teardown", PlayerRegistry.state(&"p0") == host
		and PlayerRegistry.state(&"p1") == guest and host != guest
		and t.autoload("EconomyManager").gold == 711 and guest.gold == 99)
