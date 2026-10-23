extends RefCounted
## Section multiplayer_state (package MP3-player-state): PlayerState rows, save v3 shape,
## and the single-player equivalence contract (one row == the old global backpack/quest log).
const SECTION := "multiplayer_state"
const TIMEOUT_S := 90.0

class RejectSection extends Node:
	var reject := false
	func to_dict() -> Dictionary: return {"v": 1}
	func from_dict(_data: Dictionary) -> bool: return not reject
	func reset() -> void: pass


func run(t) -> void:
	_test_defaults(t)
	_test_roundtrip(t)
	_test_reset_profile(t)
	_test_save_shape(t)
	await _test_save_and_social(t)


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


func _test_save_and_social(t) -> void:
	await t.go_menu()
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SaveManager")
	var social: Node = t.autoload("SocialManager")
	var eco: Node = t.autoload("EconomyManager")
	var quests: Node = t.autoload("QuestManager")
	var previous_dir: String = sm.save_dir
	var previous_auto: bool = sm.autosave_enabled
	var scratch := "user://multiplayer_save_test"
	sm.save_dir = scratch
	sm.autosave_enabled = false
	t.on_cleanup(func() -> void:
		sm.save_dir = previous_dir
		sm.autosave_enabled = previous_auto
	)
	gm.start_new_game("Host", gm.CharacterType.ANIMAL, "Shared Farm")
	gm.change_phase(gm.GamePhase.MENU)
	gm.clear_flag(GameManager.FLAG_INTRO_PENDING)
	eco.gold = 111
	quests.accept_quest(&"lost_cat")
	var guest := PlayerRegistry.state(&"p1")
	guest.reset_profile("Guest", 1, &"fairy_stardust")
	guest.gold = 222
	guest.hotbar = ["wood"]
	guest.player_pos = Vector2(33.25, -44.5)
	PlayerRegistry.for_player(&"p1", func() -> void:
		eco.add_item(&"wood", 4, true)
		quests.accept_quest(&"fix_roof")
	)
	var events := []
	var listener := func(pid: StringName, npc: StringName, hearts: int) -> void: events.append([str(pid), str(npc), hearts])
	EventBus.friend_changed.connect(listener)
	social.add_points("baker_maja", 200, &"debug", {"toast": false})
	social.add_points("baker_maja", 500, &"debug", {"toast": false, "player_id": &"p1"})
	EventBus.friend_changed.disconnect(listener)
	t.check("hearts_per_player", social.hearts("baker_maja", &"p0") == 2 and social.hearts("baker_maja", &"p1") == 5
		and events == [["p0", "baker_maja", 2], ["p1", "baker_maja", 5]])
	t.check("friend_mirrors_per_player", gm.flag_int(&"friend_baker_maja") == 2 and PlayerRegistry.state(&"p1").flags.get("friend_baker_maja") == 5
		and not gm.world_flags.has(&"friend_baker_maja"))
	social.for_player(&"p1", func() -> void: social.on_conversation_finished("gardener_hoppe", 2))
	t.check("weekly_chat_per_player", social.chat_available("gardener_hoppe") and not social.for_player(&"p1", func() -> bool: return social.chat_available("gardener_hoppe"))
		and not PlayerRegistry.state(&"p0").flags.has("friend_last_gardener_hoppe"))
	var payload: Dictionary = sm.gather_payload()
	t.check("v3_sections", payload.meta.version == 3 and payload.players.rows.size() == 2 and not payload.has("economy") and not payload.has("quests")
		and sm.FEATURE_ORDERS.players == 15)
	t.check("summary_roster", payload.meta.summary.players.size() == 2 and payload.meta.summary.players[0].name == "Host"
		and payload.meta.summary.players[1].name == "Guest" and payload.meta.summary.players[1].gold == 222)
	var social_before: Dictionary = social.to_dict()
	var wrote: bool = sm.save_game(0)
	gm.start_new_game("Other", gm.CharacterType.GHOST, "Other Farm")
	var loaded: bool = sm.load_game(0)
	t.check("v3_round_trip", wrote and loaded and PlayerRegistry.state(&"p0").gold == 111 and PlayerRegistry.state(&"p1").gold == 222
		and PlayerRegistry.state(&"p1").name == "Guest" and PlayerRegistry.state(&"p1").peer_id == 2 and PlayerRegistry.state(&"p1").player_pos == Vector2(33.25, -44.5)
		and social.hearts("baker_maja", &"p0") == 2 and social.hearts("baker_maja", &"p1") == 5)
	t.check("quest_runtime_restored_for_guest", PlayerRegistry.for_player(&"p1", func() -> bool: return quests.is_active(&"fix_roof")))
	t.check("social_roundtrip_all_players", JSON.stringify(social.to_dict(), "", true) == JSON.stringify(social_before, "", true))
	var drift: Dictionary = social_before.duplicate(true)
	drift.by_player.p0["removed_friend"] = {"p": 100}
	drift.by_player.p1["removed_friend"] = {"p": 200}
	var warning := "SocialManager.from_dict: unknown NPC 'removed_friend' kept in the orphans bucket"
	t.allow(warning)
	social.from_dict(drift)
	var orphaned: Dictionary = social.to_dict().orphans_by_player
	t.check("orphan_rows_keep_player_owner", orphaned.p0.removed_friend.p == 100 and orphaned.p1.removed_friend.p == 200)
	t.expect_allowed(warning, 2)
	social.from_dict(social_before)
	# A later section rejecting a load must restore all profiles and friendship mirrors.
	var reject := RejectSection.new()
	sm.register_section("multiplayer_reject", reject, 90)
	var rollback_file: bool = sm.save_game(1)
	PlayerRegistry.state(&"p0").gold = 333
	PlayerRegistry.state(&"p1").gold = 444
	social.add_points("baker_maja", 200, &"debug", {"toast": false, "player_id": &"p1"})
	reject.reject = true
	var refused: bool = not sm.load_game(1)
	t.check("rollback_restores_every_profile", rollback_file and refused and sm.last_error.get("code") == "apply"
		and PlayerRegistry.state(&"p0").gold == 333 and PlayerRegistry.state(&"p1").gold == 444
		and PlayerRegistry.state(&"p1").flags.get("friend_baker_maja") == 7
		and social.hearts("baker_maja", &"p1") == 7, "host %d guest %d, mirror %s" % [PlayerRegistry.state(&"p0").gold, PlayerRegistry.state(&"p1").gold, PlayerRegistry.state(&"p1").flags])
	sm.unregister_section("multiplayer_reject")
	reject.free()
	var entered: bool = sm.load_and_enter(0)
	await t.until(func() -> bool: return t.world() != null, 15.0)
	await t.frames(5)
	t.check("title_load_retains_roster", entered and t.world() != null and t.world().roster.rows.size() == 2
		and PlayerRegistry.state(&"p1").gold == 222 and PlayerRegistry.state(&"p1").name == "Guest")
	await t.go_menu()
	t.check("world_teardown_retains_roster", PlayerRegistry.state(&"p1").gold == 222 and sm.has_section("players"))
	# A genuine v2 layout must migrate every field without mutating the input.
	var legacy: Dictionary = payload.duplicate(true)
	legacy.meta.version = 2
	legacy["economy"] = payload.players.rows.p0.duplicate(true)
	legacy["quests"] = payload.players.rows.p0.quests.duplicate(true)
	legacy.erase("players")
	legacy.game.world_flags["friend_baker_maja"] = 2
	legacy.world["player_pos"] = [1.25, -9.5]
	legacy.world["hotbar"] = ["hoe_wooden"]
	var verdict: Dictionary = sm.validate_payload(legacy)
	t.check("v2_migrates", verdict.ok and verdict.payload.meta.version == 3 and verdict.payload.players.rows.p0.gold == 111
		and verdict.payload.players.rows.p0.flags.friend_baker_maja == 2 and verdict.payload.players.rows.p0.hotbar == ["hoe_wooden"]
		and verdict.payload.players.rows.p0.player_pos == [1.25, -9.5] and not verdict.payload.game.world_flags.has("friend_baker_maja")
		and not legacy.has("players") and legacy.game.world_flags.has("friend_baker_maja"))
	var four: Dictionary = payload.duplicate(true)
	for slot in [2, 3]:
		var extra := PlayerState.new(StringName("p%d" % slot), slot + 1)
		extra.reset_profile("Hero %d" % slot, slot)
		extra.gold = (slot + 1) * 111
		four.players.rows[str(extra.player_id)] = extra.to_dict()
	var four_loaded: bool = sm.validate_payload(four).ok and sm._apply_payload(four).ok
	t.check("four_profiles_roundtrip", four_loaded and PlayerRegistry._states.size() == 4 and PlayerRegistry.state(&"p3").gold == 444
		and PlayerRegistry.state(&"p2").character_type == 2)
	sm.load_game(0)
	var invalid_cases := []
	for key in ["p0", "p1"]:
		var invalid: Dictionary = payload.duplicate(true)
		invalid.players.rows[key].quests = {"active": {"broken": {"id": "different"}}}
		invalid_cases.append(invalid)
	var mismatched: Dictionary = payload.duplicate(true)
	mismatched.players.rows.p1.id = "p0"
	invalid_cases.append(mismatched)
	var empty: Dictionary = payload.duplicate(true)
	empty.players.rows = {}
	invalid_cases.append(empty)
	var rejected := true
	for invalid in invalid_cases: rejected = rejected and not sm.validate_payload(invalid).ok
	t.check("invalid_roster_rejected_before_apply", rejected and PlayerRegistry.state(&"p1").gold == 222)
	for file in DirAccess.get_files_at(scratch): DirAccess.remove_absolute(scratch.path_join(file))
	DirAccess.remove_absolute(scratch)
	sm.save_dir = previous_dir
	sm.autosave_enabled = previous_auto
	gm.start_new_game("Tester", gm.CharacterType.ANIMAL, "Test Farm")
	gm.change_phase(gm.GamePhase.MENU)
