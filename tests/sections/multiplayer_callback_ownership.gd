extends RefCounted
const SECTION := "multiplayer_callback_ownership"
const TIMEOUT_S := 120.0
const Rollback := preload("res://tests/sections/multiplayer_rollback.gd")

func _lily_failed(t, saves: Node, kind: String) -> void:
	var late := Rollback.LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("mp4_callback_late", late, 1000)
	t.check(kind + "_eligible", SocialManager.befriend_reason(&"fairy_lily") == "" and SocialManager.hearts(&"fairy_lily") == 0 and EconomyManager.can_add_item(&"dress_sun_meadow") and EconomyManager.can_add_item(&"sofa_leaf") and saves.save_game(0))
	var origin := PlayerRegistry.peek_state(&"p0")
	var entered: Array = []
	var gains: Array = []
	var replace := func():
		if not entered.is_empty() or WardrobeManager.count_total(&"dress_sun_meadow") == 0: return
		entered.append(kind)
		late.rejects = 1
		entered.append(saves.load_game(0))
		entered.append(late.calls)
		entered.append(PlayerRegistry.peek_state(&"p0") == origin)
	var owned := func():
		if kind == "lily_failed_store": replace.call()
	var gained := func(_pid, id, n):
		gains.append([id, n])
		if kind == "lily_failed_item" and id == &"dress_sun_meadow": replace.call()
	WardrobeManager.owned_changed.connect(owned)
	EventBus.item_gained.connect(gained)
	SocialManager.add_hearts(&"fairy_lily", 6)
	EventBus.item_gained.disconnect(gained)
	WardrobeManager.owned_changed.disconnect(owned)
	t.check(kind + "_complete_rollback", entered == [kind, false, 2, true] and not str(saves.last_error).contains("incomplete"), "genuine late rejection and complete origin identity restoration; %s" % [entered])
	t.check(kind + "_earned_pair_continues", SocialManager.hearts(&"fairy_lily") == 6 and WardrobeManager.count_total(&"dress_sun_meadow") == 1 and FurnitureManager.count_total(&"sofa_leaf") == 1 and LootService.claimed.has("fairy_lily:3") and LootService.claimed.has("fairy_lily:6") and gains == [[&"dress_sun_meadow", 1], [&"sofa_leaf", 1]], "actual post-rollback remaining gift progresses automatically once")
	var gold := EconomyManager.gold
	LootService.check_friend_gifts("fairy_lily")
	t.check(kind + "_next_progress_once", EconomyManager.gold == gold and SocialManager.add_points(&"fairy_lily", 1).ok and SocialManager.points(&"fairy_lily") == 6 * SocialManager.points_per_heart() + 1 and saves.save_game(1) and not saves.network_admission_blocked(), "no duplicate gift sale; future current operation is live")
	saves.unregister_section("mp4_callback_late")
	late.free()


func run(t) -> void:
	var saves: Node = t.autoload("SaveManager")
	var prior: String = saves.save_dir
	t.on_cleanup(func(): saves.save_dir = prior)
	for kind: String in ["lily_item", "lily_store", "lily_failed_item", "lily_failed_store", "adopt_clothing", "adopt_furniture", "migration_clothing", "migration_furniture", "reset_modal", "reset_character", "reset_modal_failed", "reset_character_failed"]:
		if OS.get_environment("MP4_CALLBACK_CASE") != "" and OS.get_environment("MP4_CALLBACK_CASE") != kind: continue
		if not await t.start_world(): return
		saves.save_dir = "user://mp4-callback-" + kind
		DirAccess.make_dir_recursive_absolute(saves.save_dir)
		if kind == "lily_item": _lily_item(t, saves)
		elif kind == "lily_store": _lily_store(t, saves)
		elif kind.begins_with("adopt_"): _adopt(t, saves, kind)
		elif kind.begins_with("migration_"): _migration(t, saves, kind)
		elif kind.begins_with("reset_"): _reset(t, saves, kind)
		else: _lily_failed(t, saves, kind)
		await t.go_menu()

func _reset(t, saves: Node, kind: String) -> void:
	if kind.ends_with("_failed"):
		_reset_failed(t, saves, kind)
		return
	EconomyManager.add_item(&"stone", 17, true)
	EconomyManager.gold = 873
	QuestManager.accept_quest(&"lost_cat")
	GameManager.play_time_seconds = 222
	t.check(kind + "_winner_saved", QuestManager.is_active(&"lost_cat") and saves.save_game(1), "distinguishable real progressed disk winner")
	GameManager.push_modal(&"mp4_reset")
	var entered: Array = []
	var winner: Dictionary = {}
	var replace := func():
		if not entered.is_empty(): return
		entered.append(kind)
		entered.append(saves.load_game(1))
		winner.merge(_snapshot(saves))
		entered.append(EconomyManager.gold == 873 and EconomyManager.count_item(&"stone") == 17 and QuestManager.is_active(&"lost_cat") and saves.current_slot == 1 and not saves.pending_world.is_empty())
	var modal := func(stack):
		if kind == "reset_modal" and stack.is_empty(): replace.call()
	var character := func(_pid, _skin):
		if kind == "reset_character": replace.call()
	EventBus.modal_changed.connect(modal)
	EventBus.player_character_changed.connect(character)
	GameManager.start_new_game("OldReset", GameManager.CharacterType.ANIMAL)
	EventBus.player_character_changed.disconnect(character)
	EventBus.modal_changed.disconnect(modal)
	t.check(kind + "_real_success", entered == [kind, true, true], "successful nested load at actual reset final observer; %s" % [entered])
	t.check(kind + "_winner_after_unwind", not winner.is_empty() and _matches(saves, winner) and EconomyManager.gold == 873 and EconomyManager.count_item(&"stone") == 17 and QuestManager.is_active(&"lost_cat"), "no obsolete new_game_started reset wave may erase winner/run/pending")
	t.check(kind + "_future_live", SocialManager.add_points(&"fairy_lily", 1).ok and saves.save_game(2) and not saves.network_admission_blocked())

func _reset_failed(t, saves: Node, kind: String) -> void:
	var late := Rollback.LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("mp4_callback_late", late, 1000)
	EconomyManager.gold = 873
	t.check(kind + "_saved", saves.save_game(1))
	var old_run: String = saves.run_id
	GameManager.push_modal(&"mp4_reset")
	var entered: Array = []
	var waves: Array = []
	var replace := func():
		if not entered.is_empty(): return
		entered.append(kind)
		# Reset has installed a fresh sparse profile but has not run manager
		# defaults yet. Establish the real closed-codec preimage for this FULL
		# rollback control; raw sparse failures remain separate evidence.
		EconomyManager.from_dict(EconomyManager.to_dict())
		QuestManager.from_dict(QuestManager.to_dict())
		WardrobeManager.to_dict()
		HomeManager.from_dict(HomeManager.to_dict())
		var profile := PlayerRegistry.peek_state(&"p0")
		late.rejects = 1
		entered.append(saves.load_game(1))
		entered.append(late.calls)
		entered.append(PlayerRegistry.peek_state(&"p0") == profile)
	var modal := func(stack):
		if kind == "reset_modal_failed" and stack.is_empty(): replace.call()
	var character := func(_pid, _skin):
		if kind == "reset_character_failed": replace.call()
	var wave := func(): waves.append(true)
	EventBus.modal_changed.connect(modal)
	EventBus.player_character_changed.connect(character)
	EventBus.new_game_started.connect(wave)
	GameManager.start_new_game("CompleteReset", GameManager.CharacterType.ANIMAL)
	EventBus.new_game_started.disconnect(wave)
	EventBus.player_character_changed.disconnect(character)
	EventBus.modal_changed.disconnect(modal)
	t.check(kind + "_genuine_restore", entered == [kind, false, 2, true], "failed nested apply restores the new reset profile, not successful replacement; %s %s" % [entered, saves.last_error])
	t.check(kind + "_complete_wave", waves == [true] and GameManager.player_name == "CompleteReset" and saves.run_id != old_run and saves.current_slot == -1 and saves.pending_world.is_empty() and EconomyManager.gold == int(GameManager.config_value("economy.starting_gold", 500)) and EconomyManager.count_item(&"hoe_wooden") == 1 and QuestManager.active_quests.is_empty() and QuestManager.pending_rewards.is_empty() and LootService.claimed.is_empty() and GameManager.modal_stack().is_empty(), "ordinary complete reset wave remains enabled after a failed nested load")
	t.check(kind + "_next_progress", EconomyManager.add_item(&"stone", 1, true) and saves.save_game(2) and not saves.network_admission_blocked())
	saves.unregister_section("mp4_callback_late")
	late.free()

func _migration(t, saves: Node, kind: String) -> void:
	var clothing := kind == "migration_clothing"
	var item: StringName = &"dress_sun_meadow" if clothing else &"sofa_leaf"
	var late := Rollback.LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("mp4_callback_late", late, 1000)
	t.check(kind + "_saved", saves.save_game(1))
	var entered: Array = []
	var gains: Array = []
	var source := PlayerRegistry.peek_state(&"p0")
	var callback := func():
		if not entered.is_empty(): return
		if (WardrobeManager.count_total(item) if clothing else FurnitureManager.count_total(item)) == 0: return
		entered.append("owned")
		late.rejects = 1
		entered.append(saves.load_game(1))
		entered.append(late.calls)
		entered.append(PlayerRegistry.peek_state(&"p0") == source)
	var furniture := func(reason):
		if reason == &"stock": callback.call()
	var gained := func(_pid, id, n): gains.append([id, n])
	if clothing: WardrobeManager.owned_changed.connect(callback)
	else: EventBus.furniture_changed.connect(furniture)
	EventBus.item_gained.connect(gained)
	var raw := {"inventory": [{"id": "stone", "amount": 2}, {"id": str(item), "amount": 1}, {"id": str(item), "amount": 1}]}
	EconomyManager.from_dict(raw)
	EconomyManager.adopt_misrouted()
	EventBus.item_gained.disconnect(gained)
	if clothing: WardrobeManager.owned_changed.disconnect(callback)
	else: EventBus.furniture_changed.disconnect(furniture)
	t.check(kind + "_failed_load_restores", entered == ["owned", false, 2, true] and not str(saves.last_error).contains("incomplete"), "actual failed nested disk apply, certified same-owner recovery; %s %s" % [entered, saves.last_error])
	t.check(kind + "_exact_migration", EconomyManager.count_item(&"stone") == 2 and EconomyManager.count_item(item) == 2 and (WardrobeManager.count_total(item) == 1 if clothing else FurnitureManager.count_total(item) == 1) and gains.is_empty(), "both rows retained exactly: one owned plus refused duplicate in backpack; no repeat item_gained; inventory=%s store=%s gains=%s" % [EconomyManager.inventory, WardrobeManager.count_total(item) if clothing else FurnitureManager.count_total(item), gains])
	t.check(kind + "_future_live", EconomyManager.add_item(&"stone", 1, true) and EconomyManager.count_item(&"stone") == 3 and saves.save_game(2))
	saves.unregister_section("mp4_callback_late")
	late.free()

func _adopt(t, saves: Node, kind: String) -> void:
	EconomyManager.add_item(&"stone", 7, true)
	EconomyManager.add_item(&"wood", 4, true)
	EconomyManager.gold = 873
	var clothing := kind == "adopt_clothing"
	var item: StringName = &"dress_sun_meadow" if clothing else &"sofa_leaf"
	var legacy: Dictionary = saves.gather_payload().duplicate(true)
	legacy["players"]["rows"]["p0"]["inventory"] = [{"id": "stone", "amount": 2, "meta": {}}, {"id": str(item), "amount": 1, "meta": {}}]
	legacy["wardrobe"]["owned"].erase("dress_sun_meadow")
	legacy["players"]["rows"]["p0"]["wardrobe"]["owned"].erase("dress_sun_meadow")
	legacy["furniture"]["stock"].erase("sofa_leaf")
	var valid: Dictionary = saves.validate_payload(legacy)
	var file := FileAccess.open(saves.slot_path(0), FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy, "", true, true))
	file.close()
	t.check(kind + "_eligible", valid.ok and saves.save_game(1) and EconomyManager.inventory.size() >= 2 and WardrobeManager.can_add(&"dress_sun_meadow"), "valid legacy incoming wardrobe slot and distinct real winner backpack")
	var entered: Array = []
	var winner: Dictionary = {}
	var old_rows: Array = []
	var tails: Array = []
	var finished: Array = []
	var callback := func():
		if not entered.is_empty() or EconomyManager.count_item(item) < 1: return
		if not clothing and FurnitureManager.count_total(item) < 1: return
		if clothing and WardrobeManager.count_total(item) < 1: return
		entered.append(EconomyManager.inventory.size() == 2 and EconomyManager.inventory[1].id == item)
		old_rows.append(PlayerRegistry.peek_state(&"p0"))
		entered.append(saves.load_game(1))
		winner.merge(_snapshot(saves))
		finished.append(true)
	var outfit := func(_pid, _outfit):
		if not finished.is_empty(): tails.append("outfit")
	var presets := func():
		if not finished.is_empty(): tails.append("presets")
	var furniture := func(reason):
		if not finished.is_empty(): tails.append(reason)
		elif not clothing and reason == &"stock": callback.call()
	var hygge := func(_score, _level):
		if not finished.is_empty(): tails.append("hygge")
	EventBus.hygge_changed.connect(hygge)
	EventBus.outfit_changed.connect(outfit)
	WardrobeManager.presets_changed.connect(presets)
	EventBus.furniture_changed.connect(furniture)
	if clothing: WardrobeManager.owned_changed.connect(callback)
	var loaded: bool = saves.load_game(0)
	if clothing: WardrobeManager.owned_changed.disconnect(callback)
	EventBus.hygge_changed.disconnect(hygge)
	EventBus.furniture_changed.disconnect(furniture)
	WardrobeManager.presets_changed.disconnect(presets)
	EventBus.outfit_changed.disconnect(outfit)
	t.check(kind + "_store_pre_removal", entered == [true, true] and old_rows.size() == 1, "actual store commit callback, while source slot still present, successfully loads winner; %s" % [entered])
	t.check(kind + "_winner_no_slot_loss", not loaded and not winner.is_empty() and _matches(saves, winner) and EconomyManager.count_item(&"stone") == 7 and EconomyManager.count_item(&"wood") == 4, "old adoption may not remove winner's unrelated row or continue migration")
	t.check(kind + "_no_stale_notifications", tails.is_empty(), "revoked old loader must not publish replacement's outfit/presets/furniture as its migration; %s" % [tails])
	t.check(kind + "_future_progress", EconomyManager.add_item(&"stone", 1, true) and EconomyManager.count_item(&"stone") == 8 and saves.save_game(2) and not saves.network_admission_blocked(), "normal current-owner item and disk-save remain live")

func _snapshot(saves: Node) -> Dictionary:
	return {"game": GameManager.to_dict().duplicate(true), "profile": PlayerRegistry.peek_state(&"p0"), "row": PlayerRegistry.peek_state(&"p0").to_dict().duplicate(true), "loot": LootService.to_dict().duplicate(true), "furniture": FurnitureManager.to_dict().duplicate(true), "pending": saves.pending_world.duplicate(true), "run": saves.run_id, "slot": saves.current_slot}

func _matches(saves: Node, snap: Dictionary) -> bool:
	return _snapshot(saves) == snap

func _lily_item(t, saves: Node) -> void:
	var other := PlayerRegistry.state(&"p1")
	PlayerRegistry.for_player(&"p1", func():
		EconomyManager.from_dict(EconomyManager.to_dict())
		QuestManager.from_dict(QuestManager.to_dict()))
	var unrelated := other.to_dict().duplicate(true)
	var old := PlayerRegistry.peek_state(&"p0")
	var first_claims := LootService.claimed
	t.check("lily_item_eligible", SocialManager.befriend_reason(&"fairy_lily") == "" and SocialManager.hearts(&"fairy_lily") == 0 and not LootService.claimed.has("fairy_lily:3") and not LootService.claimed.has("fairy_lily:6") and EconomyManager.can_add_item(&"dress_sun_meadow") and EconomyManager.can_add_item(&"sofa_leaf") and saves.save_game(0), "actual authored Lily pair fits; real lower-heart winner disk save")
	var entered: Array = []
	var winner: Dictionary = {}
	var callback := func(pid: StringName, id: StringName, n: int):
		if id != &"dress_sun_meadow" or not entered.is_empty(): return
		entered.append([pid, id, n, LootService.claimed.has("fairy_lily:3"), WardrobeManager.count_total(id)])
		entered.append(saves.load_game(0))
		winner.merge(_snapshot(saves))
		entered.append(SocialManager.hearts(&"fairy_lily") == 0 and FurnitureManager.count_total(&"sofa_leaf") == 0 and not LootService.claimed.has("fairy_lily:6"))
	EventBus.item_gained.connect(callback)
	var result: Dictionary = SocialManager.add_hearts(&"fairy_lily", 6)
	EventBus.item_gained.disconnect(callback)
	t.check("lily_item_committed_boundary", result.ok and entered == [[&"p0", &"dress_sun_meadow", 1, true, 1], true, true], "first gift and its claim committed before actual successful winner load; %s" % [entered])
	t.check("lily_item_no_stale_second", not winner.is_empty() and _matches(saves, winner) and FurnitureManager.count_total(&"sofa_leaf") == 0 and not LootService.claimed.has("fairy_lily:6"), "winner immediately and after old gift loop unwind must be identical")
	t.check("lily_item_origin_accounted", old.wardrobe.owned.get("dress_sun_meadow", 0) == 1 and first_claims.has("fairy_lily:3") and not first_claims.has("fairy_lily:6") and PlayerRegistry.peek_state(&"p1").to_dict() == unrelated, "one committed first-origin gift/claim; no unrelated row loss")
	SocialManager.add_hearts(&"fairy_lily", 6)
	LootService.check_friend_gifts("fairy_lily")
	t.check("lily_item_next_owner_gifts_once", WardrobeManager.count_total(&"dress_sun_meadow") == 1 and FurnitureManager.count_total(&"sofa_leaf") == 1 and LootService.claimed.has("fairy_lily:3") and LootService.claimed.has("fairy_lily:6") and not saves.network_admission_blocked(), "loaded owner can earn both actual gifts once without borrowed cached eligibility")

func _lily_store(t, saves: Node) -> void:
	t.check("lily_store_eligible", SocialManager.befriend_reason(&"fairy_lily") == "" and SocialManager.hearts(&"fairy_lily") == 0 and EconomyManager.can_add_item(&"dress_sun_meadow") and saves.save_game(0), "real wardrobe and actual lower-heart winner save")
	var entered: Array = []
	var winner: Dictionary = {}
	var gained: Array = []
	var origin := PlayerRegistry.peek_state(&"p0")
	var callback := func():
		if not entered.is_empty() or WardrobeManager.count_total(&"dress_sun_meadow") == 0: return
		entered.append(not LootService.claimed.has("fairy_lily:3"))
		entered.append(saves.load_game(0))
		winner.merge(_snapshot(saves))
	var item := func(_pid, id, _n): gained.append(id)
	WardrobeManager.owned_changed.connect(callback)
	EventBus.item_gained.connect(item)
	SocialManager.add_hearts(&"fairy_lily", 6)
	EventBus.item_gained.disconnect(item)
	WardrobeManager.owned_changed.disconnect(callback)
	t.check("lily_store_precommit_boundary", entered == [true, true] and origin.wardrobe.owned.get("dress_sun_meadow", 0) == 1, "real owned_changed before loot accounting successfully replaces origin")
	t.check("lily_store_no_stale_accounting", not winner.is_empty() and _matches(saves, winner) and gained.is_empty() and not LootService.claimed.has("fairy_lily:3") and not LootService.claimed.has("fairy_lily:6"), "old store return cannot announce gains or commit claims/keepsakes on replacement; %s" % [gained])
	SocialManager.add_hearts(&"fairy_lily", 6)
	t.check("lily_store_future_earned", WardrobeManager.count_total(&"dress_sun_meadow") == 1 and FurnitureManager.count_total(&"sofa_leaf") == 1 and LootService.claimed.has("fairy_lily:3") and LootService.claimed.has("fairy_lily:6"), "replacement genuinely earns the authored pair via normal automatic Social route")
